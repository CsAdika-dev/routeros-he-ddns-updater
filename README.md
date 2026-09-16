# HE DDNS Updater RouterOS script

This repository contains a **RouterOS script** (`update-he-dns.rsc`) that keeps a
dynamic DNS entry on the *HE.net* service up‑to‑date for both IPv4 and IPv6.
It can work in two different modes:

* **interface** – the script reads the current address from a specified network
  interface.
* **nat** – the script queries an external service (via `:tool fetch`) to obtain
  the public IP address.

---

## Configuration (variables at the top of the script)

| Variable | Description |
|----------|-------------|
| `enableIpv4` | Set to `true` to enable IPv4 updates. |
| `enableIpv6` | Set to `true` to enable IPv6 updates. |
| `ddnsMode`   | Either `"interface"` or `"nat"`. Determines how the public address is obtained. |
| `ddnshost`   | The fully‑qualified domain name you registered at HE.net. |
| `ddnspass`   | The password (or token) associated with the hostname. |
| `waninterfacev4` | Interface name used when `ddnsMode = "interface"` for IPv4. |
| `waninterfacev6` | Interface name used when `ddnsMode = "interface"` for IPv6. |
| `ipv4URL` / `ipv4file` | URL and temporary file used when `ddnsMode = "nat"` for IPv4. |
| `ipv6pool`   | (Optional) IPv6 address pool when using NAT‑style updates. |
| `updateURL`  | The HE.net update endpoint – usually `https://dyn.dns.he.net/nic/update`. |

The script expects the **global variables** `ipv4ddns` and `ipv6ddns` to be
initialised elsewhere (e.g., in a separate configuration file) with the last
known good IP addresses. This allows the script to detect changes before sending
an update request.

---

## How it works

1. **Acquire the current address** – depending on the chosen mode the script
   either reads the address from the specified interface or fetches it from an
   external web service.
2. **Strip the subnet mask** – the address string may contain a CIDR suffix
   (e.g., `192.0.2.10/32`). The script removes everything after the slash.
3. **Compare with the stored value** – if the address has not changed, the script
   logs an informational message and stops.
4. **Send the update** – when the address differs, a POST request is sent to the
   HE.net dynamic DNS endpoint with `hostname`, `password`, and the new IP.
5. **Handle the response** – on a successful response the script checks the returned
   data for the keywords `good` or `nochg` using RouterOS's `[:find]` function.
   The condition verifies that the keyword is present (`[:find ...] != -1`). If
   either keyword is found, the stored global variable (`ipv4ddns`/`ipv6ddns`)
   is updated to the new address.

All steps contain error handling that logs warnings or errors to the RouterOS
log, ensuring you can troubleshoot issues via the system log.

---

## Usage

1. **Copy the script** into the RouterOS `/system script` section (or import it
   from a file).
2. **Create/adjust the global variables** `ipv4ddns` and `ipv6ddns` with the
   current values (or initialise them to an empty string).
3. **Set the variables at the top of the script** to match your environment.
4. **Schedule the script** with a scheduler entry, e.g. every 5 minutes:

   ```
   /system scheduler add name="HE‑DDNS" interval=5m on-event="/system script run update-he-dns"
   ```

   Adjust the interval as needed.

## Initialization script

An **init‑env.rsc** script is provided to initialise the required global variables
`ipv4ddns` and `ipv6ddns` before the main updater runs. It simply creates the
globals with empty string values:

```routeros
/system script add name=init-env source="/system script run init-env.rsc"
```

You can schedule it to run at startup:

```routeros
/system schedule add name=init-env.rsc on-event=init-env.rsc start-time=startup interval=0
```

This ensures the updater has defined variables to compare against, avoiding
undefined‑variable warnings.

---

## Logging

The script uses the RouterOS `:log` command with the following prefixes:

* `DDNS: info` – normal operation, address unchanged or update sent.
* `DDNS: warning` – non‑critical issues (e.g., skipping an update because the
  address could not be resolved).
* `DDNS: error` – serious problems that prevent the update.

You can view the logs with:

```
/log print where topics~"DDNS"
```

---

## License & Contribution

This script is provided *as‑is* without warranty. Feel free to fork the
repository, improve the logic, or adapt it to your own environment. If you find
issues, open an issue or submit a pull request.

---

*Last updated: September 2026*
