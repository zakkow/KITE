# KITE (Keyboard Intelligence & Motor Adaptation)

KITE is an intelligent, motor-adaptive custom iOS keyboard built specifically to eliminate physical and software typing friction for individuals with motor impairments (such as Parkinson's essential tremor, cerebral palsy, or atypical physical touch scatter). Rather than forcing users to adapt their hands to rigid software key targets, **KITE adapts software key targets to the user's hands**.

## Core Philosophy & Architecture

Standard virtual keyboards rely on rigid, static rectangular hitboxes. KITE replaces these with a **Dual-Engine Architecture** that learns your unique physical typing patterns and mathematically reshapes the keyboard beneath your fingers in real time.

### 1. Spatial Motor Engine (The Math)
Every time you tap the screen, KITE calculates the true variance and Exponentially Weighted Moving Average (EWMA) of your taps relative to the intended keys.
- **Directional Drift**: If KITE mathematically detects you consistently tapping the right edge of 'H' when you meant 'J' (high Signal-to-Noise Ratio), it silently shifts the geometric center of the 'J' key toward your natural thumb strike zone.
- **Tremor Scatter**: If KITE detects erratic, multi-directional taps (low Signal-to-Noise Ratio), it expands the acceptance radius of the key rather than forcing a false direction.

### 2. Multi-Tier Linguistic Safety Net
A purely geometric engine could accidentally auto-correct valid words into gibberish. KITE layers a powerful linguistic engine on top to ensure 100% semantic safety:
- **Auto-Learning Typo Engine**: Manually fix a typo once, and KITE learns it. Do it 3 times, and KITE silently corrects it for you in the background forever.
- **Grammar & Context Parsing**: KITE looks retroactively at sentence boundaries to fix contractions (e.g., automatically changing "ill" to "I'll" based on the following word).
- **The Dictionary Veto**: Even if the spatial math is 99% confident you meant to hit 'V' instead of 'B', if swapping that letter breaks a valid English word (like turning "lobe" into "love"), the Linguistic Engine vetoes the physical correction, prioritizing dictionary accuracy.

## 100% On-Device & Zero-Trust Privacy

A keyboard has access to everything you type: passwords, medical history, bank details. **Maximum privacy is not a feature; it is a requirement.**

1. **Zero Network Calls:** KITE does not have network access. All spatial math, EWMA processing, and machine learning happen 100% locally on your iPhone's silicon.
2. **App Group Sandboxing:** Data is securely isolated within Apple’s `group.com.kite.shared` sandbox container. Nothing ever leaves your device.
3. **Open-Source Trust:** You don't have to trust us—you compile the app yourself. By downloading this repository and building it on your own machine, you guarantee that the code running on your phone is exactly the code you see here.

---

## Installation Guide (Compile it Yourself)

To ensure absolute privacy and security, KITE is not downloaded from the App Store. You will compile it directly to your iPhone using Apple's official developer tools.

### Prerequisites
- A Mac running macOS 13+.
- Xcode installed (Free on the Mac App Store).
- An iPhone (iOS 16+).
- A Lightning or USB-C cable to connect your iPhone to your Mac.

### Step-by-Step Deployment

**1. Download the Code**
- Click the green `<> Code` button at the top of this repository and select **Download ZIP**.
- Unzip the folder on your Mac and open `KITE(Final).xcodeproj` in Xcode.

**2. Configure Your Apple ID**
- In Xcode, go to the top menu bar: `Xcode` > `Settings` > `Accounts`.
- Click the `+` button in the bottom left, select **Apple ID**, and log in with your standard Apple ID. (You do not need a paid developer account).

**3. Assign the Signature**
- In Xcode's left sidebar, click the top-level blue `KITE(Final)` project file.
- Under the **Targets** list (in the middle pane), select the `KITE(Final)` app target.
- Go to the **Signing & Capabilities** tab.
- Check "Automatically manage signing" and select your Apple ID from the **Team** dropdown.
- *Crucial:* Do the exact same thing for the `custom keyboard` target in the list. Both targets must be signed by your Apple ID.

**4. Connect & Trust Your iPhone**
- Plug your iPhone into your Mac using the USB cable. (If prompted on your phone, tap "Trust This Computer").
- On your iPhone, open `Settings` > `Privacy & Security`. Scroll to the very bottom and tap **Developer Mode**. Toggle it ON and restart your phone.

**5. Build and Run**
- At the top of the Xcode window, look for the device selector (it usually says "Any iOS Device" or an iPhone Simulator). Click it and select your physically connected iPhone from the list.
- Press the big **Play (Run)** button ▶️ in the top left corner of Xcode.
- Xcode will compile KITE and install it directly onto your phone.

**6. Enable the Keyboard**
- Once the KITE app opens on your phone, go to your iPhone's `Settings` > `General` > `Keyboard` > `Keyboards`.
- Tap **Add New Keyboard...** and select **KITE**.
- Tap **KITE** again in the list and toggle **Allow Full Access**. *(Note: iOS shows a scary warning here by default for all custom keyboards. Rest assured, because you compiled this yourself, you know exactly where your data is going—nowhere).*

You are now ready to type with KITE! Open any text field, tap the globe icon 🌐 on your keyboard to switch to KITE, and let it learn your hands.
