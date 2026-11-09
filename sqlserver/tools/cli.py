"""Entry point for Compose swaps, Kubernetes rendering, and image builds."""
import argparse
import os
import subprocess
import sys

from common import ALLOY_IMAGE, LANGUAGES, REPLACEMENTS, ROOT, build_spec, image_name
from compose import run_compose
from kubernetes import alloy_image, render_kubernetes


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="deployment", required=True)
    for name in ("compose", "kubernetes", "build"):
        command = commands.add_parser(name)
        command.add_argument("language", choices=LANGUAGES)
        command.add_argument("replacement", choices=REPLACEMENTS,
                             help="Replace MySQL, PostgreSQL, or both with SQL Server RDS")
        if name == "compose":
            command.add_argument("--env-file", default=os.environ.get("BOOKSTORE_ENV_FILE"))
            command.add_argument("command", nargs=argparse.REMAINDER)
        else:
            command.add_argument("--registry", default="")
            command.add_argument("--tag", help="Image tag (default: sqlserver-<selection>)")
        if name == "kubernetes":
            command.add_argument("--output")
        if name == "build":
            command.add_argument("--push", action="store_true")
    return result


def build_images(args):
    for name in ("products", "checkout", "shipping", "frontend"):
        spec = build_spec(args.language, name, args.replacement)
        image = image_name(args.language, name, args.registry, args.tag)
        command = ["docker", "build", "-t", image, "-f",
                   str(os.path.join(spec["context"], spec["dockerfile"]))]
        arguments = dict(spec.get("args", {}))
        if name == "frontend":
            for key in ("VITE_FARO_ENDPOINT", "VITE_ASSERTS_ENV", "VITE_SESSION_REPLAY"):
                if key in os.environ:
                    arguments[key] = os.environ[key]
        for key, value in arguments.items():
            command.extend(("--build-arg", f"{key}={value}"))
        subprocess.run(command + [spec["context"]], check=True)
        if args.push:
            subprocess.run(["docker", "push", image], check=True)
    build_alloy(args)
    return 0


def build_alloy(args):
    image = alloy_image(args)
    subprocess.run(["docker", "build", "-t", image, "--build-arg",
                    f"ALLOY_IMAGE={ALLOY_IMAGE}", str(ROOT / "sqlserver/alloy")], check=True)
    if args.push:
        subprocess.run(["docker", "push", image], check=True)


def main():
    args = parser().parse_args()
    if args.deployment != "compose" and args.tag is None:
        args.tag = f"sqlserver-{args.replacement}"
    try:
        return {"compose": run_compose, "kubernetes": render_kubernetes,
                "build": build_images}[args.deployment](args)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"swap-db: {error}", file=sys.stderr)
        return 1
