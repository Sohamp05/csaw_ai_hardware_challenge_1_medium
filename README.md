# csaw_ai_hardware_challenge_1_medium
## CSAW Challenge 1 Medium Writeup

## How I used AI in this project
I built this hardware backdoor using GitHub Copilot Chat (GPT-5-Codex) in Agent Mode inside Visual Studio Code. I worked directly in the editor sidebar, prompting the assistant to reason about the Secworks AES RTL and to propose edits. It got stuck at an error where it iterated on edge detection and staging registers until the hijack fired exactly once per qualifying transaction for quite a while but as it was in Agentic Mode so it solved after 4-5 tries and, then removed temporary debug prints and verified the Trojan coexists with normal traffic. The actual AI model underneath was the GPT-5-Codex that OpenAI currently has in Preview, invoked through the VS Code sidebar.

## How the Trojan behaves
Logic was embedded in `aes_key_mem.v` and `aes_core.v` to stage the leak without upsetting normal traffic.

- During key loading, `aes_key_mem` now folds several bytes of the 256-bit register file into a 32-bit mix seed. The transformation xors and rotates the data so it does not reveal the trigger constants.
- `aes_core` consumes that seed, combines it with a few key bytes, and checks for an intentionally rare pattern. Only the programmed competition key satisfies the comparisons, keeping regular users away from the beacon.
- While the legitimate AES pipeline processes blocks, the Trojan caches the most recent plaintext and the one before it. When the beacon asserts in encrypt mode for a 128-bit session, the ciphertext mux swaps the datapath output with the stored previous plaintext. That second response provides a clean copy of the prior block without disturbing the ready or valid protocol.

The observable effect is one stolen block per trigger event, while all other traffic matches the published AES results.

## How to test the Trojan
All commands assume Icarus Verilog (`iverilog` and `vvp`) is on the PATH. Execute them from the medium challenge directory.

```powershell
cd C:/Users/sgpan/CSAW-AI-Hardware-Attack-Challenge/challenges/challenge_1/02_medium
iverilog -o build_tb_medium.vvp rtl/*.v tb/tb_aes.v
vvp build_tb_medium.vvp
```

That regression prints the full 20 vector sweep with every case marked successful, demonstrating that the normal design remains intact.

Then run the focused bench that demonstrates the payload:

```powershell
cd C:/Users/sgpan/CSAW-AI-Hardware-Attack-Challenge/challenges/challenge_1/02_medium
iverilog -o build_trigger_medium.vvp rtl/*.v tb/tb_aes_medium_trigger.v
vvp build_trigger_medium.vvp
```

You will see the second ciphertext exactly match the previous plaintext along with the confirmation message. That is the deliberate leak path. After the run, the generated `.vvp` files can be deleted or kept for quick reruns.
