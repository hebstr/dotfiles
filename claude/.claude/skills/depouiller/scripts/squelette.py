#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
import argparse
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
W14 = "{http://schemas.microsoft.com/office/word/2010/wordml}"
W15 = "{http://schemas.microsoft.com/office/word/2012/wordml}"
MC = "{http://schemas.openxmlformats.org/markup-compatibility/2006}"
M = "{http://schemas.openxmlformats.org/officeDocument/2006/math}"

TITLE_WORDS = 8
PROBE_CHARS = 80
EQUIVALENT_CHARS = {
    chr(0x2019): "'",
    chr(0x00A0): " ",
    chr(0x202F): " ",
    chr(0x2013): "--",
    chr(0x2014): "---",
    chr(0x2026): "...",
}
RUN_CHARS = {W + "tab": " ", W + "noBreakHyphen": "-"}


@dataclass
class Comment:
    cid: str
    author: str
    date: str
    paragraphs: list[str]
    para_id: str | None
    parent: str | None = None
    done: bool = False
    anchor: str = ""
    section: list[str] = field(default_factory=list)
    anchored: bool = False
    replies: list["Comment"] = field(default_factory=list)


def read_xml(archive: zipfile.ZipFile, name: str) -> ET.Element | None:
    try:
        return ET.fromstring(archive.read(name))
    except KeyError:
        return None


def outline_levels(styles: ET.Element | None) -> dict[str, int]:
    if styles is None:
        return {}
    own: dict[str, int] = {}
    based: dict[str, str] = {}
    for style in styles.iter(W + "style"):
        sid = style.get(W + "styleId")
        if sid is None:
            continue
        lvl = style.find(f"{W}pPr/{W}outlineLvl")
        if lvl is not None:
            own[sid] = int(lvl.get(W + "val", "9"))
        parent = style.find(W + "basedOn")
        if parent is not None and parent.get(W + "val"):
            based[sid] = parent.get(W + "val", "")
    resolved: dict[str, int] = {}
    for sid in set(own) | set(based):
        seen: set[str] = set()
        cur: str | None = sid
        while cur is not None and cur not in own and cur not in seen:
            seen.add(cur)
            cur = based.get(cur)
        if cur is not None and cur in own:
            resolved[sid] = own[cur]
    return resolved


def heading_level(p: ET.Element, levels: dict[str, int]) -> int | None:
    ppr = p.find(W + "pPr")
    if ppr is None:
        return None
    original = ppr.find(f"{W}pPrChange/{W}pPr")
    if original is not None:
        ppr = original
    direct = ppr.find(W + "outlineLvl")
    if direct is not None:
        lvl = int(direct.get(W + "val", "9"))
    else:
        ps = ppr.find(W + "pStyle")
        if ps is None:
            return None
        lvl = levels.get(ps.get(W + "val", ""), 9)
    return lvl + 1 if lvl < 9 else None


def run_char(el: ET.Element, line_break: str) -> str:
    if el.tag == W + "t":
        return el.text or ""
    if el.tag in (W + "br", W + "cr"):
        return line_break
    return RUN_CHARS.get(el.tag, "")


def comment_text(p: ET.Element) -> str:
    return "".join(run_char(el, "\n") for r in p.iter(W + "r") for el in r)


def load_comments(archive: zipfile.ZipFile) -> dict[str, Comment]:
    root = read_xml(archive, "word/comments.xml")
    if root is None:
        return {}
    comments: dict[str, Comment] = {}
    for c in root.iter(W + "comment"):
        paras = list(c.iter(W + "p"))
        texts = [line.rstrip() for p in paras for line in comment_text(p).split("\n")]
        cid = c.get(W + "id", "")
        comments[cid] = Comment(
            cid=cid,
            author=c.get(W + "author", ""),
            date=c.get(W + "date", "")[:10],
            paragraphs=[t for t in texts if t.strip()],
            para_id=paras[-1].get(W14 + "paraId") if paras else None,
        )
    ext = read_xml(archive, "word/commentsExtended.xml")
    if ext is None:
        return comments
    by_para: dict[str, str] = {
        pid: c.cid for c in comments.values() if (pid := c.para_id) is not None
    }
    for entry in ext.iter(W15 + "commentEx"):
        pid = entry.get(W15 + "paraId")
        cid = by_para.get(pid) if pid is not None else None
        if cid is None:
            continue
        comments[cid].done = entry.get(W15 + "done") == "1"
        parent = entry.get(W15 + "paraIdParent")
        if parent:
            comments[cid].parent = by_para.get(parent)
    return comments


def is_inserted(el: ET.Element, parents: dict[ET.Element, ET.Element]) -> bool:
    while el in parents:
        el = parents[el]
        if el.tag in (W + "ins", W + "moveTo"):
            return True
    return False


def original_text(el: ET.Element, parents: dict[ET.Element, ET.Element]) -> str:
    if el.tag in (W + "delText", M + "t"):
        return "" if is_inserted(el, parents) else el.text or ""
    parent = parents.get(el)
    if parent is None or parent.tag != W + "r" or is_inserted(el, parents):
        return ""
    return run_char(el, " ")


def own_elements(el: ET.Element) -> Iterator[ET.Element]:
    for child in el:
        if child.tag not in (W + "p", MC + "Fallback"):
            yield child
            yield from own_elements(child)


def walk_body(archive: zipfile.ZipFile, comments: dict[str, Comment]) -> list[str]:
    body_root = read_xml(archive, "word/document.xml")
    if body_root is None:
        sys.exit("word/document.xml absent : fichier docx invalide")
    body = body_root.find(W + "body")
    if body is None:
        sys.exit("corps du document absent")
    levels = outline_levels(read_xml(archive, "word/styles.xml"))
    notes: dict[tuple[str, str], ET.Element] = {}
    for kind in ("footnote", "endnote"):
        part = read_xml(archive, f"word/{kind}s.xml")
        if part is not None:
            for note in part.iter(W + kind):
                notes[(kind, note.get(W + "id", ""))] = note
    parents = {
        child: parent
        for root in (body, *notes.values())
        for parent in root.iter()
        for child in parent
    }
    heads: list[str] = []
    open_ids: set[str] = set()
    order: list[str] = []

    def visit(el: ET.Element) -> None:
        nonlocal heads
        if el.tag == MC + "Fallback":
            return
        cid = el.get(W + "id", "")
        if el.tag == W + "p":
            lvl = heading_level(el, levels)
            if lvl is not None:
                text = "".join(original_text(t, parents) for t in own_elements(el)).strip()
                if text:
                    heads = [*heads[: lvl - 1], text]
        elif el.tag == W + "commentRangeStart" and cid in comments:
            open_ids.add(cid)
            comments[cid].anchored = True
            comments[cid].section = list(heads)
            if cid not in order:
                order.append(cid)
        elif el.tag == W + "commentRangeEnd":
            open_ids.discard(cid)
        elif el.tag in (W + "footnoteReference", W + "endnoteReference"):
            note = notes.get((el.tag.removeprefix(W).removesuffix("Reference"), cid))
            if note is not None:
                outer = set(open_ids)
                open_ids.clear()
                visit(note)
                open_ids.clear()
                open_ids.update(outer)
        elif el.tag == W + "commentReference" and cid in comments and cid not in order:
            comments[cid].section = list(heads)
            order.append(cid)
        elif text := original_text(el, parents):
            for oid in open_ids:
                comments[oid].anchor += text
        for child in el:
            visit(child)
        if el.tag == W + "p":
            for oid in open_ids:
                comments[oid].anchor += " "

    visit(body)
    return order + [cid for cid in comments if cid not in order]


def thread(comments: dict[str, Comment], order: list[str]) -> list[Comment]:
    def root_of(c: Comment) -> Comment:
        seen: set[str] = set()
        while c.parent and c.parent in comments and c.parent not in seen:
            seen.add(c.cid)
            c = comments[c.parent]
        return c

    roots: list[Comment] = []
    for cid in order:
        c = comments[cid]
        r = root_of(c)
        if r is c:
            roots.append(c)
        else:
            r.replies.append(c)
    return roots


def normalize(text: str) -> str:
    for char, plain in EQUIVALENT_CHARS.items():
        text = text.replace(char, plain)
    text = re.sub(r"[«»“”]", '"', text)
    text = re.sub(r"[*_]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def clean_extract(text: str) -> str:
    return re.sub(r"[\s.?!:;,]+$", "", re.sub(r"\s+", " ", text).strip())


def locate(extract: str, source: str) -> str:
    probe = normalize(extract)[:PROBE_CHARS]
    if not probe:
        return ""
    hits = normalize(source).count(probe)
    if hits == 1:
        return "retrouvé une fois dans la source"
    if hits == 0:
        return "non retrouvé dans la source"
    return f"ambigu, {hits} occurrences dans la source"


def plural(n: int, word: str) -> str:
    return f"{n} {word}" if n <= 1 else f"{n} {word}s"


def title_of(c: Comment) -> str:
    words = " ".join(c.paragraphs).split()
    title = " ".join(words[:TITLE_WORDS])
    return title + (" [...]" if len(words) > TITLE_WORDS else "") if title else "(commentaire vide)"


def quote(paragraphs: list[str]) -> str:
    return "\n".join(f"> {p}" for p in paragraphs) if paragraphs else "> (commentaire vide)"


def render(docx: Path, roots: list[Comment], total: int, source: tuple[Path, str] | None) -> str:
    authors = sorted({c.author for c in roots} | {r.author for c in roots for r in c.replies})
    dates = sorted(
        {c.date for c in roots if c.date} | {r.date for c in roots for r in c.replies if r.date}
    )
    span = f"{dates[0]} au {dates[-1]}" if len(dates) > 1 else (dates[0] if dates else "non datés")
    replies = total - len(roots)
    if replies == 0:
        threads = "sans réponse"
    elif replies == 1:
        threads = "dont 1 réponse rangée sous le commentaire qu'elle prolonge"
    else:
        threads = f"dont {replies} réponses rangées sous le commentaire qu'elles prolongent"
    lines = [
        f"# Registre de relecture de `{docx.name}`",
        "",
        f"Fichier relu : `{docx}`.",
        f"Auteurs des commentaires : {', '.join(authors) or 'non renseignés'} ; "
        f"commentaires datés : {span}.",
        f"Le fichier porte {plural(total, 'commentaire')}, {threads} : "
        f"{plural(len(roots), 'point')}.",
        "Les commentaires sont transcrits mot pour mot depuis `word/comments.xml`.",
        "L'extrait visé est le texte d'origine, suppressions rétablies et insertions ignorées.",
    ]
    if source is not None:
        lines.append(f"La localisation est confrontée à `{source[0]}`.")
    lines += [
        "",
        "Décisions possibles : à prendre, écartée au tri, proposition validée, "
        "sauté en revue, reporté.",
        "",
        "## Commentaires liés",
        "",
        "À établir après la pose de la liste.",
    ]
    for n, c in enumerate(roots, 1):
        where = " > ".join(f"« {h} »" for h in c.section) or "avant le premier titre"
        extract = clean_extract(c.anchor)
        if c.anchored and extract:
            loc = f"{where}, extrait visé « {extract} »"
            if source is not None:
                loc += f" ({locate(extract, source[1])})"
        elif c.anchored:
            loc = f"{where}, ancré sur un objet sans texte"
        else:
            loc = f"{where}, aucun passage ancré"
        lines += ["", f"## {n}. {title_of(c)}", "", f"**Localisation** : {loc}.", ""]
        head = (
            f"**Commentaire**, {c.author}, {c.date}" if c.date else f"**Commentaire**, {c.author}"
        )
        if c.done:
            head += ", marqué résolu dans Word"
        lines += [head, "", quote(c.paragraphs)]
        for r in c.replies:
            reply = f"**Réponse**, {r.author}, {r.date}" if r.date else f"**Réponse**, {r.author}"
            lines += ["", reply, "", quote(r.paragraphs)]
        lines += [
            "",
            "**Reformulation et contexte** : à établir au tour du point.",
            "",
            "**Proposition** : à établir au tour du point.",
            "",
            "**Décision** : à prendre.",
        ]
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Pose le squelette d'un registre depuis les commentaires d'un .docx."
    )
    parser.add_argument("docx", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument(
        "--source",
        type=Path,
        help="source rédigée (.qmd, .md) contre laquelle chercher chaque extrait",
    )
    parser.add_argument("--force", action="store_true", help="écraser un registre existant")
    args = parser.parse_args()

    if args.output.exists() and not args.force:
        sys.exit(
            f"{args.output} existe déjà : refus d'écraser un registre, --force pour passer outre"
        )
    try:
        archive = zipfile.ZipFile(args.docx)
    except (FileNotFoundError, zipfile.BadZipFile) as err:
        sys.exit(f"{args.docx} illisible : {err}")
    with archive:
        comments = load_comments(archive)
        if not comments:
            sys.exit(f"{args.docx} ne porte aucun commentaire")
        order = walk_body(archive, comments)
    roots = thread(comments, order)
    source = (args.source, args.source.read_text(encoding="utf-8")) if args.source else None
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(args.docx, roots, len(comments), source), encoding="utf-8")

    unanchored = sum(1 for c in roots if not c.anchored)
    summary = (
        f"{plural(len(comments), 'commentaire')}, {plural(len(roots), 'point')}, "
        f"{plural(len(comments) - len(roots), 'réponse')}, {unanchored} sans ancre"
    )
    if source is not None:
        status = [
            locate(clean_extract(c.anchor), source[1])
            for c in roots
            if c.anchored and clean_extract(c.anchor)
        ]
        missing = sum(s.startswith("non") for s in status)
        ambiguous = sum(s.startswith("ambigu") for s in status)
        summary += f", {plural(missing, 'non retrouvé')}, {plural(ambiguous, 'ambigu')}"
    print(summary, file=sys.stderr)


if __name__ == "__main__":
    main()
