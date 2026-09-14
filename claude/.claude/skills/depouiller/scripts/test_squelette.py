import importlib.util
import subprocess
import sys
import zipfile
from pathlib import Path

import pytest

SCRIPT = Path(__file__).with_name("squelette.py")
_spec = importlib.util.spec_from_file_location("squelette", SCRIPT)
assert _spec is not None and _spec.loader is not None
squelette = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(squelette)

APOS = chr(0x2019)

NS = (
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
    'xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"'
)

STYLES = (
    f"<w:styles {NS}>"
    '<w:style w:type="paragraph" w:styleId="Titre1"><w:name w:val="heading 1"/>'
    '<w:pPr><w:outlineLvl w:val="0"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Titre2"><w:name w:val="heading 2"/>'
    '<w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="SousTitre"><w:name w:val="Sous-titre maison"/>'
    '<w:basedOn w:val="Titre2"/></w:style>'
    '<w:style w:type="paragraph" w:styleId="TocHeading"><w:name w:val="TOC Heading"/>'
    '<w:basedOn w:val="Titre1"/><w:pPr><w:outlineLvl w:val="9"/></w:pPr></w:style>'
    "</w:styles>"
)


def run(text: str) -> str:
    return f'<w:r><w:t xml:space="preserve">{text}</w:t></w:r>'


def para(*parts: str, style: str | None = None) -> str:
    ppr = f'<w:pPr><w:pStyle w:val="{style}"/></w:pPr>' if style else ""
    return f"<w:p>{ppr}{''.join(parts)}</w:p>"


def start(cid: int) -> str:
    return f'<w:commentRangeStart w:id="{cid}"/>'


def end(cid: int) -> str:
    return f'<w:commentRangeEnd w:id="{cid}"/><w:r><w:commentReference w:id="{cid}"/></w:r>'


def ref(cid: int) -> str:
    return f'<w:r><w:commentReference w:id="{cid}"/></w:r>'


def inserted(text: str) -> str:
    return f'<w:ins w:id="900" w:author="R">{run(text)}</w:ins>'


def deleted(text: str) -> str:
    return (
        '<w:del w:id="901" w:author="R">'
        f'<w:r><w:delText xml:space="preserve">{text}</w:delText></w:r></w:del>'
    )


def text_box(text: str) -> str:
    inner = f"<w:txbxContent>{para(run(text))}</w:txbxContent>"
    return (
        '<w:r><mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
        f'<mc:Choice Requires="wps">{inner}</mc:Choice><mc:Fallback>{inner}</mc:Fallback>'
        "</mc:AlternateContent></w:r>"
    )


def comment(cid: int, texts: list[str], author: str = "Relectrice") -> str:
    paras = "".join(f'<w:p w14:paraId="P{cid}{i}">{run(t)}</w:p>' for i, t in enumerate(texts))
    return (
        f'<w:comment w:id="{cid}" w:author="{author}" w:date="2026-09-14T10:00:00Z">'
        f"{paras}</w:comment>"
    )


def last_para(cid: int, texts: list[str]) -> str:
    return f"P{cid}{len(texts) - 1}"


def make_docx(
    path: Path,
    body: str,
    comments: list[str],
    extended: list[tuple[str, str | None, bool]] | None = None,
    styles: str | None = STYLES,
    footnotes: str | None = None,
) -> Path:
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("word/document.xml", f"<w:document {NS}><w:body>{body}</w:body></w:document>")
        if footnotes is not None:
            z.writestr("word/footnotes.xml", f"<w:footnotes {NS}>{footnotes}</w:footnotes>")
        z.writestr("word/comments.xml", f"<w:comments {NS}>{''.join(comments)}</w:comments>")
        if styles is not None:
            z.writestr("word/styles.xml", styles)
        if extended is not None:
            entries = "".join(
                f'<w15:commentEx w15:paraId="{pid}"'
                + (f' w15:paraIdParent="{parent}"' if parent else "")
                + f' w15:done="{int(done)}"/>'
                for pid, parent, done in extended
            )
            z.writestr(
                "word/commentsExtended.xml", f"<w15:commentsEx {NS}>{entries}</w15:commentsEx>"
            )
    return path


def build(
    tmp_path: Path, docx: Path, *extra: str, output: str = "notes.md"
) -> tuple[subprocess.CompletedProcess[str], Path]:
    out = tmp_path / output
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), str(docx), "-o", str(out), *extra],
        capture_output=True,
        text=True,
        check=False,
    )
    return proc, out


def entries(md: str) -> list[str]:
    parts = md.split("\n## ")
    return [p for p in parts[1:] if p[:1].isdigit()]


def test_transcription_mot_pour_mot(tmp_path: Path) -> None:
    texts = [f"qu{APOS}est ce qui est apporté  ici ?", "Deuxième paragraphe, sans retouche."]
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), run("passage"), end(1)),
        [comment(1, texts)],
    )
    proc, out = build(tmp_path, docx)
    assert proc.returncode == 0, proc.stderr
    md = out.read_text(encoding="utf-8")
    assert f"> qu{APOS}est ce qui est apporté  ici ?\n> Deuxième paragraphe, sans retouche." in md


def test_reponses_rangees_sous_leur_racine(tmp_path: Path) -> None:
    racine, reponse, relance = ["Question ?"], ["Réponse."], ["Relance."]
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), start(2), start(3), run("passage"), end(1), end(2), end(3)),
        [comment(1, racine), comment(2, reponse, "Autre"), comment(3, relance)],
        extended=[
            (last_para(1, racine), None, False),
            (last_para(2, reponse), last_para(1, racine), False),
            (last_para(3, relance), last_para(2, reponse), False),
        ],
    )
    proc, out = build(tmp_path, docx)
    assert proc.returncode == 0, proc.stderr
    items = entries(out.read_text(encoding="utf-8"))
    assert len(items) == 1
    assert items[0].count("**Réponse**") == 2
    assert items[0].index("> Réponse.") < items[0].index("> Relance.")


def test_sans_comments_extended_chaque_commentaire_est_un_point(tmp_path: Path) -> None:
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), start(2), run("passage"), end(1), end(2)),
        [comment(1, ["Question ?"]), comment(2, ["Réponse."])],
        extended=None,
    )
    proc, out = build(tmp_path, docx)
    assert proc.returncode == 0, proc.stderr
    assert len(entries(out.read_text(encoding="utf-8"))) == 2


def test_ancre_sur_plusieurs_paragraphes(tmp_path: Path) -> None:
    docx = make_docx(
        tmp_path / "a.docx",
        para(run("avant "), start(1), run("fin du premier")) + para(run("début du second"), end(1)),
        [comment(1, ["Remarque"])],
    )
    _, out = build(tmp_path, docx)
    assert "extrait visé « fin du premier début du second »" in out.read_text(encoding="utf-8")


def test_extrait_en_texte_d_origine(tmp_path: Path) -> None:
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), run("le texte "), deleted("ancien"), inserted("nouveau"), end(1)),
        [comment(1, ["Remarque"])],
    )
    _, out = build(tmp_path, docx)
    md = out.read_text(encoding="utf-8")
    assert "extrait visé « le texte ancien »" in md
    assert "nouveau" not in md


def test_insertion_supprimee_ensuite_absente_de_l_extrait(tmp_path: Path) -> None:
    fantome = f'<w:ins w:id="905" w:author="A">{deleted("fantome ")}</w:ins>'
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), run("le texte "), fantome, run("reste"), end(1)),
        [comment(1, ["Remarque"])],
    )
    _, out = build(tmp_path, docx)
    md = out.read_text(encoding="utf-8")
    assert "extrait visé « le texte reste »" in md
    assert "fantome" not in md


def test_deplacement_suivi_garde_la_seule_origine(tmp_path: Path) -> None:
    body = para(
        start(1),
        run("A "),
        f'<w:moveFrom w:id="902" w:author="R">{run("bouge")}</w:moveFrom>',
        run(" B "),
        f'<w:moveTo w:id="903" w:author="R">{run("bouge")}</w:moveTo>',
        end(1),
    )
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Remarque"])])
    _, out = build(tmp_path, docx)
    assert "extrait visé « A bouge B »" in out.read_text(encoding="utf-8")


def test_zone_de_texte_lue_une_seule_fois(tmp_path: Path) -> None:
    body = para(run("Titre"), text_box("encart"), style="Titre1") + para(
        start(1), run("avant "), text_box("dans la boite"), run(" apres"), end(1)
    )
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Remarque"])])
    _, out = build(tmp_path, docx)
    md = out.read_text(encoding="utf-8")
    assert "**Localisation** : « Titre », extrait visé « avant dans la boite apres »." in md


@pytest.mark.parametrize(
    "body",
    [
        start(1) + para(run("un")) + para(run("deux"), end(1)) + para(run("reste")),
        para(start(1), run("un"))
        + para(run("deux"))
        + '<w:commentRangeEnd w:id="1"/>'
        + para(ref(1))
        + para(run("reste")),
    ],
    ids=["debut_hors_paragraphe", "fin_hors_paragraphe"],
)
def test_marqueurs_hors_paragraphe(tmp_path: Path, body: str) -> None:
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Remarque"])])
    _, out = build(tmp_path, docx)
    assert "extrait visé « un deux »." in out.read_text(encoding="utf-8")


def test_commentaire_dans_une_note(tmp_path: Path) -> None:
    body = (
        para(run("Chapitre"), style="Titre1")
        + para(run("autre"), style="Titre1")
        + para(
            start(2),
            run("avant"),
            '<w:r><w:footnoteReference w:id="7"/></w:r>',
            run(" apres"),
            end(2),
        )
        + para(run("Suite"), style="Titre1")
    )
    note = f'<w:footnote w:id="7">{para(start(1), run("dans la note"), end(1))}</w:footnote>'
    docx = make_docx(
        tmp_path / "a.docx",
        body,
        [comment(1, ["Sur la note"]), comment(2, ["Sur le corps"])],
        footnotes=note,
    )
    proc, out = build(tmp_path, docx)
    assert proc.returncode == 0, proc.stderr
    md = out.read_text(encoding="utf-8")
    assert "**Localisation** : « autre », extrait visé « dans la note »." in md
    assert "**Localisation** : « autre », extrait visé « avant apres »." in md
    items = entries(md)
    assert "Sur le corps" in items[0] and "Sur la note" in items[1]


def test_tabulations_et_sauts_de_ligne_separent_les_mots(tmp_path: Path) -> None:
    taquets = (
        '<w:pPr><w:pStyle w:val="Titre1"/>'
        '<w:tabs><w:tab w:val="left" w:pos="720"/></w:tabs></w:pPr>'
    )
    body = f"<w:p>{taquets}{run('Chapitre')}</w:p>" + para(
        start(1),
        "<w:r><w:t>mot</w:t><w:tab/><w:t>suivant</w:t><w:br/><w:t>ligne</w:t></w:r>",
        end(1),
    )
    note = (
        '<w:comment w:id="1" w:author="Relectrice" w:date="2026-09-14T10:00:00Z">'
        '<w:p w14:paraId="P10"><w:r><w:t>premiere</w:t><w:br/><w:t>seconde</w:t></w:r></w:p>'
        "</w:comment>"
    )
    docx = make_docx(tmp_path / "a.docx", body, [note])
    _, out = build(tmp_path, docx)
    md = out.read_text(encoding="utf-8")
    assert "**Localisation** : « Chapitre », extrait visé « mot suivant ligne »." in md
    assert "> premiere\n> seconde" in md


def test_equation_et_objet_sans_texte(tmp_path: Path) -> None:
    omml = 'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"'
    equation = f"<m:oMath {omml}><m:r><m:t>x=2</m:t></m:r></m:oMath>"
    image = '<w:r><w:drawing><wp:inline xmlns:wp="urn:wp"/></w:drawing></w:r>'
    body = para(start(1), run("soit "), equation, run(" ici"), end(1)) + para(
        start(2), image, end(2)
    )
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Sur x"]), comment(2, ["Figure"])])
    proc, out = build(tmp_path, docx)
    md = out.read_text(encoding="utf-8")
    assert "extrait visé « soit x=2 ici »." in md
    assert "**Localisation** : avant le premier titre, ancré sur un objet sans texte." in md
    assert "0 sans ancre" in proc.stderr


def test_reponse_sans_date(tmp_path: Path) -> None:
    racine = ["Question ?"]
    sans_date = (
        '<w:comment w:id="2" w:author="Autre"><w:p w14:paraId="P20">'
        + run("Réponse.")
        + "</w:p></w:comment>"
    )
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), start(2), run("passage"), end(1), end(2)),
        [comment(1, racine), sans_date],
        extended=[(last_para(1, racine), None, False), ("P20", last_para(1, racine), False)],
    )
    _, out = build(tmp_path, docx)
    assert "**Réponse**, Autre\n" in out.read_text(encoding="utf-8")


def test_style_de_titre_d_origine_sous_suivi(tmp_path: Path) -> None:
    def restyled(text: str, now: str, before: str) -> str:
        now_style = f'<w:pStyle w:val="{now}"/>' if now else ""
        before_style = f'<w:pStyle w:val="{before}"/>' if before else ""
        change = f'<w:pPrChange w:id="904" w:author="R"><w:pPr>{before_style}</w:pPr></w:pPrChange>'
        return f"<w:p><w:pPr>{now_style}{change}</w:pPr>{run(text)}</w:p>"

    body = (
        restyled("Ancien titre", now="", before="Titre1")
        + restyled("Nouveau titre", now="Titre1", before="")
        + para(start(1), run("passage"), end(1))
    )
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Remarque"])])
    _, out = build(tmp_path, docx)
    assert "**Localisation** : « Ancien titre », extrait visé" in out.read_text(encoding="utf-8")


def test_section_par_niveau_de_plan_herite(tmp_path: Path) -> None:
    body = (
        para(run("Chapitre"), style="Titre1")
        + para(run("Table des matières"), style="TocHeading")
        + para(run("Section"), style="SousTitre")
        + para(start(1), run("passage"), end(1))
    )
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Remarque"])])
    _, out = build(tmp_path, docx)
    assert "**Localisation** : « Chapitre » > « Section », extrait visé" in out.read_text(
        encoding="utf-8"
    )


def test_titre_de_meme_niveau_remplace_le_precedent(tmp_path: Path) -> None:
    body = (
        para(run("Chapitre A"), style="Titre1")
        + para(run("Section A"), style="Titre2")
        + para(run("Chapitre B"), style="Titre1")
        + para(start(1), run("passage"), end(1))
    )
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Remarque"])])
    _, out = build(tmp_path, docx)
    assert "**Localisation** : « Chapitre B », extrait visé" in out.read_text(encoding="utf-8")


def test_commentaire_sans_ancre(tmp_path: Path) -> None:
    body = para(run("Chapitre"), style="Titre1") + para(run("texte"), ref(1))
    docx = make_docx(tmp_path / "a.docx", body, [comment(1, ["Avis général"])])
    proc, out = build(tmp_path, docx)
    assert "**Localisation** : « Chapitre », aucun passage ancré." in out.read_text(
        encoding="utf-8"
    )
    assert "1 sans ancre" in proc.stderr


def test_ponctuation_finale_retiree_de_l_extrait(tmp_path: Path) -> None:
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), run("Quelles sont les habitudes ?"), end(1)),
        [comment(1, ["Remarque"])],
    )
    _, out = build(tmp_path, docx)
    assert "extrait visé « Quelles sont les habitudes »." in out.read_text(encoding="utf-8")


@pytest.mark.parametrize(
    ("source", "attendu"),
    [
        ("Une phrase où l'analyse conjointe apparaît.", "retrouvé une fois dans la source"),
        ("Rien de commun.", "non retrouvé dans la source"),
        ("l'analyse conjointe, puis encore l'analyse conjointe", "ambigu, 2 occurrences"),
    ],
)
def test_localisation_contre_la_source(tmp_path: Path, source: str, attendu: str) -> None:
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), run(f"l{APOS}analyse conjointe"), end(1)),
        [comment(1, ["Remarque"])],
    )
    src = tmp_path / "index.qmd"
    src.write_text(source, encoding="utf-8")
    _, out = build(tmp_path, docx, "--source", str(src))
    assert attendu in out.read_text(encoding="utf-8")


def test_refus_d_ecraser_un_registre(tmp_path: Path) -> None:
    docx = make_docx(
        tmp_path / "a.docx", para(start(1), run("passage"), end(1)), [comment(1, ["Remarque"])]
    )
    out = tmp_path / "notes.md"
    out.write_text("décisions déjà prises", encoding="utf-8")
    proc, _ = build(tmp_path, docx)
    assert proc.returncode != 0
    assert out.read_text(encoding="utf-8") == "décisions déjà prises"
    forced, _ = build(tmp_path, docx, "--force")
    assert forced.returncode == 0
    assert "**Décision** : à prendre." in out.read_text(encoding="utf-8")


def test_docx_sans_commentaire(tmp_path: Path) -> None:
    path = tmp_path / "vide.docx"
    with zipfile.ZipFile(path, "w") as z:
        z.writestr(
            "word/document.xml", f"<w:document {NS}><w:body>{para(run('x'))}</w:body></w:document>"
        )
    proc, out = build(tmp_path, path)
    assert proc.returncode != 0
    assert not out.exists()


def test_commentaire_resolu_dans_word(tmp_path: Path) -> None:
    texts = ["Remarque"]
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), run("passage"), end(1)),
        [comment(1, texts)],
        extended=[(last_para(1, texts), None, True)],
    )
    _, out = build(tmp_path, docx)
    assert "marqué résolu dans Word" in out.read_text(encoding="utf-8")


def test_accord_une_seule_reponse(tmp_path: Path) -> None:
    racine, reponse = ["Question ?"], ["Réponse."]
    docx = make_docx(
        tmp_path / "a.docx",
        para(start(1), start(2), run("passage"), end(1), end(2)),
        [comment(1, racine), comment(2, reponse)],
        extended=[
            (last_para(1, racine), None, False),
            (last_para(2, reponse), last_para(1, racine), False),
        ],
    )
    proc, out = build(tmp_path, docx)
    md = out.read_text(encoding="utf-8")
    attendu = (
        "Le fichier porte 2 commentaires, dont 1 réponse rangée "
        "sous le commentaire qu'elle prolonge : 1 point."
    )
    assert attendu in md
    assert "2 commentaires, 1 point, 1 réponse," in proc.stderr


def test_accord_sans_reponse(tmp_path: Path) -> None:
    docx = make_docx(
        tmp_path / "a.docx", para(start(1), run("passage"), end(1)), [comment(1, ["Remarque"])]
    )
    proc, out = build(tmp_path, docx)
    assert "Le fichier porte 1 commentaire, sans réponse : 1 point." in out.read_text(
        encoding="utf-8"
    )
    assert "1 commentaire, 1 point, 0 réponse," in proc.stderr


def test_normalize_rend_equivalentes_les_graphies() -> None:
    assert squelette.normalize(f"l{APOS}épaule  « x »") == squelette.normalize('l\'épaule " x "')


def test_normalize_absorbe_la_typographie_de_pandoc() -> None:
    rendu = f"a {chr(0x2013)} b {chr(0x2014)} c{chr(0x2026)} em et it"
    assert squelette.normalize(rendu) == squelette.normalize("a -- b --- c... *em* et _it_")
