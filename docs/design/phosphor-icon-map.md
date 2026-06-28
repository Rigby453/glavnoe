# Material → Phosphor icon map (redesign «Kaname» §1.8)

> Canonical mapping so every screen agent migrates icons consistently. Package: `phosphor_flutter: ^2.1.0`.
> API: `PhosphorIcon(PhosphorIcons.<name>())` or `Icon(PhosphorIcons.<name>(PhosphorIconsStyle.regular))`.
> **Rule:** default = `regular` (outline). **Active/selected = `fill` + accent.** Sizes: 20 navbar/inline, 16 caption, 24 ceiling.
> For an icon NOT in this table: pick the closest Phosphor by MEANING, regular style, fill when active. Never mix in Material defaults.

## Navigation (TZ §3.1 — exact)
| role | Phosphor |
|---|---|
| Today | `sun` |
| Plan | `calendarBlank` |
| Health | `heartbeat` |
| Diary | `notebook` |
| Profile avatar | `user` (in accent-tint circle) |

## Semantic / structural (TZ §4.1 — important)
| meaning | Phosphor |
|---|---|
| **Main task (shield)** | `shield` (pending) / `shieldCheck` (done-main) |
| event | `calendar` |
| workout / fitness | `barbell` |
| call | `phone` |
| deadline / alarm | `alarm` |
| goal / flag | `flag` |
| target / track changes | `target` |
| now line node | (drawn, not an icon) |

## Common UI (by frequency)
| Material | Phosphor |
|---|---|
| add / add_circle_outline | `plus` / `plusCircle` |
| close | `x` |
| chevron_right / chevron_left | `caretRight` / `caretLeft` |
| arrow_drop_down | `caretDown` |
| arrow_back(_rounded) | `arrowLeft` |
| delete_outline / delete_sweep_outlined | `trash` / `broom` |
| check / check_circle_outline / _rounded | `check` / `checkCircle` (fill when done) |
| remove / remove_circle_outline | `minus` / `minusCircle` |
| edit_outlined | `pencilSimple` |
| search / search_off | `magnifyingGlass` / `magnifyingGlassMinus` |
| more_vert | `dotsThreeVertical` |
| tune / tune_rounded | `slidersHorizontal` (or `faders`) |
| undo | `arrowCounterClockwise` |
| refresh / sync | `arrowsClockwise` |
| copy_outlined | `copy` |
| share | `shareNetwork` |
| open_in_new | `arrowSquareOut` |
| info_outline | `info` |
| error_outline / warning_amber | `warningCircle` / `warning` |
| notifications(_outlined/_active/none) | `bell` / `bellRinging` |
| schedule / access_time | `clock` |
| history | `clockCounterClockwise` |
| circle_outlined | `circle` |
| star_rounded / star_border | `star` (fill / regular) |
| checklist_outlined | `listChecks` |
| push_pin_outlined | `pushPin` |
| swap_horiz | `arrowsLeftRight` |
| open_with | `arrowsOutCardinal` |
| photo_camera_outlined / photo_library_outlined | `camera` / `images` |
| qr_code_scanner | `qrCode` |
| broken_image_outlined | `imageBroken` |
| mic / mic_none | `microphone` |
| record_voice_over_outlined | `waveform` |
| volume_up_outlined | `speakerHigh` |
| play_arrow / play_circle_outline | `play` / `playCircle` |
| pause / pause_circle_outline | `pause` / `pauseCircle` |
| stop | `stop` |
| snooze | `clockAfternoon` (or `bellSnooze` → `bellSimpleSlash`; prefer `clockAfternoon`) |
| event_repeat_outlined | `repeat` |
| event_busy_outlined | `calendarX` |
| today_outlined | `calendarCheck` |
| upload_file_outlined | `uploadSimple` |

## Domain
| meaning (Material) | Phosphor |
|---|---|
| today / sun (wb_sunny) | `sun` ; wb_twilight → `sunHorizon` |
| sleep (bedtime / airline_seat_flat) | `moon` / `bed` |
| water (water_drop) | `drop` |
| food (restaurant / restaurant_menu) | `forkKnife` ; menu → `cookingPot` |
| shopping_cart | `shoppingCart` |
| meditation (self_improvement / spa) | `flowerLotus` (or `personSimpleTaiChi`) |
| breathing (air) | `wind` |
| posture (accessibility_new) | `personSimpleWalk` |
| screen time (apps / phone_android) | `squaresFour` / `deviceMobile` |
| games (sports_esports) | `gameController` |
| AI / auto_awesome | `sparkle` |
| insights / show_chart | `chartLine` / `chartLineUp` |
| streak (local_fire_department) | `fire` |
| freeze | `snowflake` |
| premium (workspace_premium) | `crownSimple` |
| theme (palette) | `palette` |
| language | `translate` |
| settings (gear) | `gearSix` |
| school | `graduationCap` |
| place | `mapPin` |
| logout | `signOut` |
| lock_open | `lockKeyOpen` |
| people / person_add / person_remove | `users` / `userPlus` / `userMinus` |
| timer | `timer` |
| bolt | `lightning` |
| pets | `pawPrint` |
| tips_and_updates | `lightbulb` |
| back_hand | `handPalm` |

> Decorative Kai-related icons: prefer the Kai presence itself over an icon where the TZ calls for Kai (loaders, empty states).
