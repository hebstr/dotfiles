import os


def load_config() -> dict[str, str]:
    return {
        "database_url": os.environ["DATABASE_URL"],
        "api_key": os.environ["API_KEY"],
        "sentry_dsn": os.environ["SENTRY_DSN"],
        "debug": os.environ.get("DEBUG", "false"),
    }


if __name__ == "__main__":
    config = load_config()
    print(f"starting with debug={config['debug']}")
