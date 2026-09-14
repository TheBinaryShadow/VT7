VT7 I01 input and focus diagnostic 0.1
=======================================

Purpose
-------
This bounded diagnostic records Windows 7 Croatian HR Latin keyboard behavior,
the inherited TerminalInput encoder, WPF/native HWND focus routing, Ctrl keys,
and resize messages. It is not a production input implementation.

Run
---
1. Extract the ZIP to a writable local directory. Do not run inside the ZIP.
2. Select the Croatian HR Latin keyboard layout in Windows.
3. Run RUN-INPUT-I01.cmd normally. Do not run it as administrator.
4. Follow the seven controlled steps shown in the probe window.
5. Click Complete and save. The console reports success or explains which
   required observation is missing.
6. Return the entire new Logs directory.

The two input fields intentionally record their controlled contents. Do not type
passwords, commands, host names or private terminal content into this probe.

Expected scope
--------------
- Native automatic map for KLID 0000041A with ToUnicodeEx flags 1 and 5.
- Inherited TerminalInput encodings for committed Croatian text, Ctrl+C,
  cursor mode, focus mode, repeat suppression and discovered AltGr mappings.
- Actual WPF and native HWND key/text/focus events from the user's input.
- WPF and native child resize observations.

The diagnostic does not inject global keyboard input, change the selected
system keyboard layout, launch a shell, or send any data over the network.
