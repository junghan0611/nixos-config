# THINKPAD.md — ThinkPad (work GUI) 디바이스 핸드북

> **언제 이 문서를 여는가**: `thinkpad` 디바이스 작업일 때만. 다른 디바이스 작업에는 불필요.
> 관련: [AGENTS.md](AGENTS.md) (디바이스 공통/식별).

## Local AI policy — Ollama Vulkan

- **Ollama Vulkan은 보존하되 자동 시작 비활성** (2026-05-21). 현재 로컬 임베딩을 상시 사용하지 않으므로 boot에 올리지 않는다.
- `services.ollama.enable = true`는 유지해 package/service를 남기고, `systemd.services.ollama.wantedBy = lib.mkForce []`로 multi-user auto-start만 막는다.
- 필요할 때 `sudo systemctl start ollama`로 수동 시작.
- Vulkan via Mesa RADV (AMD Radeon 780M); package auto-selected by `services.ollama.acceleration = "vulkan"`.
- Recommended model: `qwen3-embedding:4b` (2560-dim, andenken과 동일 차원).
- `OLLAMA_KEEP_ALIVE=10m` — idle 시 VRAM 자동 해제.
- History: 04-15 추가 → 04-17 revert (always-on 정책) → 05-07 재도입 (세션 임베딩 워크로드 증가) → 05-21 자동 시작 비활성.
