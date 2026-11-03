# Tuner

A guitar tuner for iPhone and iPad. It listens through the microphone, detects
the pitch of the string you play, and shows how many cents sharp or flat you are.

## Features

- Accurate pitch detection (YIN algorithm, Accelerate-optimised), well under 1 cent
  of error across the guitar's range in tests
- Auto-detects which string you are playing, or tap a string to lock onto it
- Tunings: Standard, Drop D, Half/Full Step Down, Drop C, DADGAD, Open G, Open D, Open E
- Chromatic mode for any note
- Adjustable reference pitch (A4 = 420–460 Hz)
- Screen stays awake while tuning; audio is analysed on-device and never recorded

## Requirements

- Xcode 16 or later
- iOS 17 or later

## Running it

1. Open `Tuner.xcodeproj` in Xcode.
2. Select the **Tuner** target › **Signing & Capabilities** and choose your Team
   (a free Apple ID works for installing on your own phone). If Xcode complains
   about the bundle identifier, change `com.example.Tuner` to something unique.
3. Pick your iPhone as the run destination and press **⌘R**.
   The Simulator also works and uses your Mac's microphone.
4. Allow microphone access when prompted, then pluck a string.

Run the unit tests with **⌘U**.

## How it works

| File | Role |
| --- | --- |
| `Tuner/Audio/AudioInput.swift` | `AVAudioEngine` microphone tap in measurement mode (no AGC); keeps a sliding window of samples and analyses it off the main thread |
| `Tuner/Audio/PitchDetector.swift` | YIN pitch detection with parabolic interpolation |
| `Tuner/Model/TunerModel.swift` | Smooths detections (median + low-pass), picks the target string, computes cents |
| `Tuner/Model/Note.swift`, `Tuning.swift` | Note maths and the tuning presets |
| `Tuner/Views/` | SwiftUI screens: note display, cents gauge, string buttons, settings |

The display is green when you are within ±5 cents of the target.
