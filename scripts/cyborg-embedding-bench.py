#!/usr/bin/env python3
"""Synthetic-only Qwen3-Embedding 8B benchmark; never reads a corpus."""
import argparse
import json
import math
import os
import statistics
import subprocess
import time
import urllib.error
import urllib.request

LOCAL = 'http://127.0.0.1:11435/v1/embeddings'
REMOTE = 'https://openrouter.ai/api/v1/embeddings'


def inputs(i, count):
    phrases = ('디스플레이 연결과 로컬 검색을 확인한다. ',
               'A local workstation retrieves a sample document. ')
    return [f'Synthetic query {i}:{j}. ' + phrases[j % 2] * (3, 12, 28)[j % 3]
            for j in range(count)]


def embed(url, model, texts, key=None):
    headers = {'Content-Type': 'application/json'}
    if key:
        headers['Authorization'] = 'Bearer ' + key
    req = urllib.request.Request(url, json.dumps({'model': model, 'input': texts}).encode(), headers)
    start = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=30) as reply:
            result = json.load(reply)
        rows = result['data']
        if sorted(row['index'] for row in rows) != list(range(len(texts))) or not all(
            len(row['embedding']) == 4096 and all(map(math.isfinite, row['embedding'])) for row in rows
        ):
            raise ValueError('invalid embedding response')
        return round(time.monotonic() - start, 3), result.get('usage', {}).get('prompt_tokens'), 'ok'
    except urllib.error.HTTPError as exc:
        return round(time.monotonic() - start, 3), None, f'http_{exc.code}'
    except (OSError, ValueError, TypeError, KeyError) as exc:
        return round(time.monotonic() - start, 3), None, type(exc).__name__


def gpu():
    return subprocess.check_output(['nvidia-smi', '--query-gpu=memory.used,memory.free,temperature.gpu,power.draw',
                                    '--format=csv,noheader,nounits'], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=int, choices=range(901), metavar='0..900', default=0)
    parser.add_argument('--openrouter', action='store_true', help='opt in to at most six paid synthetic requests')
    args = parser.parse_args()
    key = (os.getenv('ANDENKEN_SESSION_API_KEY') or os.getenv('OPENROUTER_API_KEY')) if args.openrouter else None
    if args.openrouter and not key:
        parser.error('no OpenRouter key in the environment')
    print('GPU used/free MiB, °C, watts:', gpu(), flush=True)
    for i, count in enumerate((1, 1, 1, 4, 4, 4)):
        texts = inputs(i, count)
        local = embed(LOCAL, 'qwen3-embedding:8b', texts)
        if local[-1] != 'ok':
            raise SystemExit(f'local v1 compatibility failed: {local}')
        remote = embed(REMOTE, 'qwen/qwen3-embedding-8b', texts, key) if key else 'disabled'
        print('paired', i, 'chunks', count, 'local', local, 'remote', remote, flush=True)
    start = time.monotonic()
    samples, errors, i, next_report = [], 0, 100, 0
    while time.monotonic() - start < args.seconds:
        elapsed, _, status = embed(LOCAL, 'qwen3-embedding:8b', inputs(i, 4))
        i += 1
        if status == 'ok':
            samples.append(elapsed)
        else:
            errors += 1
            print('local error', status, flush=True)
            if errors >= 3:
                break
            time.sleep(2)
        runtime = time.monotonic() - start
        if runtime >= next_report:
            print('load', round(runtime, 1), 'chunks', 4 * len(samples), 'errors', errors, 'gpu', gpu(), flush=True)
            next_report += 60
    if args.seconds:
        runtime = time.monotonic() - start
        print('summary', {'seconds': round(runtime, 1), 'chunks': 4 * len(samples), 'errors': errors,
                          'chunks_per_second': round(4 * len(samples) / runtime, 2),
                          'p50_batch_s': statistics.median(samples) if samples else None,
                          'p95_batch_s': sorted(samples)[math.ceil(.95 * len(samples)) - 1] if samples else None})
    return int(errors != 0)


if __name__ == '__main__':
    raise SystemExit(main())
