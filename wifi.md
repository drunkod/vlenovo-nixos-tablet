 

How to Connect to Wi-Fi on Your Tablet

Your system is configured to use NetworkManager (networking.networkmanager.enable = true;). Your user, alex, has been added to the networkmanager group, which gives you permission to manage network connections without needing to be root.

You will primarily use one of two tools from the terminal:

nmtui: A user-friendly Text User Interface (TUI). This is the recommended method.

nmcli: A powerful Command-Line Interface (CLI) for scripting and advanced use.

The Sxmo UI: Opening a Terminal

First, you need to open a terminal. In Sxmo, you typically do this through the menus:

Press the Power Button to bring up the main menu.

Use the Volume Up/Down buttons to navigate the menu.

Navigate to System and press the Power Button to select it.

Navigate to Terminal and press the Power Button to open it.

You may need to bring up the on-screen keyboard to type. This is usually done with a swipe-up gesture from the bottom of the screen or by selecting a keyboard option from a menu.

Method 1: Using nmtui (Recommended)

nmtui provides a simple, menu-driven way to manage your network connections. It's easy to navigate with the volume keys (acting as up/down arrows) and the power button (acting as Enter).

Open a terminal using the steps described above.

Launch nmtui: Type the following command and press Enter.

Generated bash
nmtui


Navigate the nmtui Menu: You will see a small menu.

Select Activate a connection and press the Power Button (Enter).

Select Your Wi-Fi Network:

nmtui will scan and list all available Wi-Fi networks (SSIDs).

Use the Volume keys to scroll down to your desired network.

With your network highlighted, press the Power Button (Enter) to select it.

Enter the Password:

A dialog box will appear asking for the Wi-Fi password.

Bring up the on-screen keyboard (svkbd or wvkbd in your case).

Carefully type the password.

Navigate to the <OK> button and press the Power Button (Enter).

Confirmation: The system will attempt to connect. A * should appear next to the network name, indicating a successful connection.

Exit nmtui: Navigate to the <Back> button, then select <Quit> from the main menu to return to your terminal.

Your tablet should now be connected to the Wi-Fi network.

Method 2: Using nmcli (Command-Line)

This method is faster if you're comfortable with the command line.

Open a terminal.

(Optional) Turn on Wi-Fi: If you suspect the Wi-Fi radio is off, turn it on:

Generated bash
nmcli radio wifi on
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

Scan for Networks: To see a list of available networks:

Generated bash
nmcli device wifi list
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

This will show you the SSID, signal strength, and security type.

Connect to a Network: Use the following command, replacing "Your-Network-Name" and "Your-Password" with your actual credentials.

Generated bash
nmcli device wifi connect "Your-Network-Name" password "Your-Password"
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

For example:

Generated bash
nmcli device wifi connect "MyHomeWiFi" password "YOUR_WIFI_PASSWORD"
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

If successful, you will see a confirmation message.

Check the Status: To verify your connection status:

Generated bash
nmcli connection show
# or for more detail:
nmcli device status
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END
Troubleshooting

If you're having trouble connecting, here are a few things to check from the terminal:

Is the Wi-Fi Adapter Blocked?
The rfkill command can tell you if your Wi-Fi is disabled by a software or hardware switch.

Generated bash
rfkill list
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

If you see "Soft blocked: yes", you can unblock it with:

Generated bash
rfkill unblock wifi
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

If it says "Hard blocked: yes", you need to enable it with a physical switch on the device.

Is the Wi-Fi Interface Detected?
Run ip a to see all network interfaces. You should see one named something like wlan0 or wlp2s0. If you don't, there might be a driver/firmware issue.

Can You Reach the Internet?
After connecting, test if you have a valid internet connection by pinging a reliable server.

Generated bash
ping 1.1.1.1
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
Bash
IGNORE_WHEN_COPYING_END

If this works, your connection is good. If it doesn't, there might be an issue with your network or the tablet's IP configuration.
