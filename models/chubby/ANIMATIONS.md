# Oki Shiba (chubby) — Animation Map

Model: `cute_chubby_dog.usdz`
FPS: 25
Total frames: 593 (23.72s)
Single baked clip: `ALLanim`

## Frame Ranges

| # | Name | Frames | Time | Duration |
|---|------|--------|------|----------|
| 1 | Idle 1 | 0-127 | 0.00-5.08s | 5.08s |
| 2 | Jump | 128-148 | 5.12-5.92s | 0.80s |
| 3 | Walk | 149-177 | 5.96-7.08s | 1.12s |
| 4 | Run 1 | 178-197 | 7.12-7.88s | 0.76s |
| 5 | Falls 1 | 198-224 | 7.92-8.96s | 1.04s |
| 6 | Wakes Up 1 | 225-253 | 9.00-10.12s | 1.12s |
| 7 | Idle 2 | 254-339 | 10.16-13.56s | 3.40s |
| 8 | No | 340-369 | 13.60-14.76s | 1.16s |
| 9 | Yes | 370-400 | 14.80-16.00s | 1.20s |
| 10 | Waving | 401-421 | 16.04-16.84s | 0.80s |
| 11 | Happy | 422-441 | 16.88-17.64s | 0.76s |
| 12 | Attack 1 | 442-460 | 17.68-18.40s | 0.72s |
| 13 | Falls 2 | 461-484 | 18.44-19.36s | 0.92s |
| 14 | Wakes Up 2 | 485-495 | 19.40-19.80s | 0.40s |
| 15 | Falls 3 | 496-519 | 19.84-20.76s | 0.92s |
| 16 | Wakes Up 3 | 520-530 | 20.80-21.20s | 0.40s |
| 17 | Run 2 | 531-546 | 21.24-21.84s | 0.60s |
| 18 | Attack 2 | 547-563 | 21.88-22.52s | 0.64s |
| 19 | DMG 1 | 564-578 | 22.56-23.12s | 0.56s |
| 20 | DMG 2 | 579-593 | 23.16-23.72s | 0.56s |

## Buddy State Mapping

| Buddy State | Animation | Behavior |
|-------------|-----------|----------|
| idle | Idle 2 | Loop |
| thinking | Idle 1 | Loop |
| coding | Walk | Loop |
| running | Run 1 | Loop |
| error | No | Play once → Idle 2 |
| success | Happy | Play once → Idle 2 |
| drop/fall | Falls 1 | Play once → Wakes Up 1 → Idle 2 |
