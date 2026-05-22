#!/usr/bin/env python3
"""
Baixa os arquivos de voz pt-br do OsmAnd e gera o mapa Dart.
Uso: python scripts/download_osmand_voice.py
"""
import json
import re
import time
import sys
from pathlib import Path
import urllib.request

GITHUB_API = "https://api.github.com/repos/osmandapp/OsmAnd-resources/contents/voice/pt-br/voice"
RAW_BASE   = "https://raw.githubusercontent.com/osmandapp/OsmAnd-resources/master/voice/pt-br"
TTS_JS_URL = f"{RAW_BASE}/pt-br_tts.js"

# Caminho relativo à raiz do projeto Flutter
PROJECT_ROOT = Path(__file__).parent.parent
OUTPUT_DIR   = PROJECT_ROOT / "assets" / "audio" / "voice" / "pt-br"
DART_OUT     = PROJECT_ROOT / "lib" / "core" / "services" / "osmand_voice_map.dart"


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "KZ-Driver/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def fetch_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "KZ-Driver/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def download_voice_files() -> list[str]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Buscando lista de arquivos no GitHub...")
    try:
        files = fetch_json(GITHUB_API)
    except Exception as e:
        print(f"Erro ao buscar lista: {e}")
        sys.exit(1)

    ogg_files = [f for f in files if f["name"].endswith(".ogg")]
    print(f"Encontrados {len(ogg_files)} arquivos .ogg\n")

    names = []
    for i, f in enumerate(ogg_files, 1):
        dest = OUTPUT_DIR / f["name"]
        if dest.exists():
            print(f"[{i:3}/{len(ogg_files)}] SKIP  {f['name']}")
            names.append(f["name"])
            continue
        url = f["download_url"]
        print(f"[{i:3}/{len(ogg_files)}] DOWN  {f['name']}...", end=" ", flush=True)
        try:
            data = fetch_bytes(url)
            dest.write_bytes(data)
            print("OK")
            names.append(f["name"])
        except Exception as e:
            print(f"ERRO  {e}")
        time.sleep(0.07)   # Rate limiting educado

    return names


def parse_tts_js(js: str) -> dict[str, list[str]]:
    """
    Parseia o pt-br_tts.js do OsmAnd.
    O arquivo usa padrões como:
      voice["turn_left"] = "left.ogg";
      voice["prepare_turn"] = prepareAudio + "left.ogg";
      dictionary["turn_left"] = tts ? "vire à esquerda" : "left.ogg";
    Retorna dict: chave → lista de arquivos .ogg
    """
    result: dict[str, list[str]] = {}

    # Padrão 1: voice["key"] = "file.ogg";
    for m in re.finditer(r'voice\["([^"]+)"\]\s*=\s*"([^"]+\.ogg)"', js):
        key, ogg = m.group(1), m.group(2)
        result.setdefault(key, []).append(ogg)

    # Padrão 2: dictionary["key"] = tts ? "text" : "file.ogg";
    for m in re.finditer(
        r'dictionary\["([^"]+)"\]\s*=\s*tts\s*\?\s*"[^"]*"\s*:\s*"([^"]+\.ogg)"', js
    ):
        key, ogg = m.group(1), m.group(2)
        if key not in result:
            result[key] = [ogg]

    # Padrão 3: voice["key"] = someVar + "file.ogg";  (composição)
    for m in re.finditer(
        r'voice\["([^"]+)"\]\s*=\s*[^;]*?"([^"]+\.ogg)"[^;]*;', js
    ):
        key = m.group(1)
        oggs = re.findall(r'"([^"]+\.ogg)"', m.group(0))
        if key not in result and oggs:
            result[key] = oggs

    return result


def generate_dart(voice_map: dict[str, list[str]], all_files: list[str]) -> str:
    """Gera o arquivo Dart com o mapa de voz."""
    lines = [
        "// AUTO-GERADO por scripts/download_osmand_voice.py",
        "// Não edite manualmente — rode o script novamente para atualizar.",
        "",
        "// Mapeamento de chaves OsmAnd → arquivo(s) .ogg em assets/audio/voice/pt-br/",
        "const Map<String, List<String>> kOsmAndVoiceMap = {",
    ]
    for key in sorted(voice_map):
        files = voice_map[key]
        file_list = ", ".join(f"'{f}'" for f in files)
        lines.append(f"  '{key}': [{file_list}],")
    lines.append("};")
    lines.append("")
    lines.append("// Todos os arquivos disponíveis (para debug):")
    lines.append(f"// {len(all_files)} arquivos baixados")
    return "\n".join(lines)


def main():
    print("=" * 60)
    print("OsmAnd pt-br Voice Downloader - KZ Driver")
    print("=" * 60)

    all_files = download_voice_files()

    print(f"\nBuscando pt-br_tts.js para gerar mapa Dart...")
    try:
        js = fetch_bytes(TTS_JS_URL).decode("utf-8")
        voice_map = parse_tts_js(js)
        print(f"Entradas encontradas no TTS JS: {len(voice_map)}")
    except Exception as e:
        print(f"Aviso: não conseguiu parsear TTS JS: {e}")
        voice_map = {}

    dart_code = generate_dart(voice_map, all_files)
    DART_OUT.write_text(dart_code, encoding="utf-8")
    print(f"\nDart gerado: {DART_OUT}")
    print(f"Arquivos de voz: {OUTPUT_DIR}")
    print(f"Total: {len(all_files)} .ogg | {len(voice_map)} entradas no mapa")
    print("\nProximo passo: adicionar 'assets/audio/voice/pt-br/' no pubspec.yaml")


if __name__ == "__main__":
    main()
