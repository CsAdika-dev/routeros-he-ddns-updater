# --- Configuration ---
:local enableIpv4 true
:local enableIpv6 true

# Mód: "nat" vagy "interface"
:local ddnsMode "interface"

:global ipv4ddns
:global ipv6ddns
# required FQDN. eg: justhost.domain.tld
:local ddnshost ""
# required 
:local ddnspass ""
# if enableIpv4 = true and mode = "interface"
:local waninterfacev4 "" 
# if enableIpv6 true
:local waninterfacev6 "" 
# required eg: https://dyn.dns.he.net/nic/update
:local updateURL "https://dyn.dns.he.net/nic/update"
# if enabledIpv4 true and mode = "nat"
# A URL that returns text containing an IP address.
:local ipv4URL ""
:local ipv4file "mypublicipv4.txt"
:local ipv4fresh ""
:local ipv6fresh ""
:local ipv4error false
:local ipv6error false

# --- IPv4 query & refresh ---
:if ($enableIpv4) do={
    :do {
        :if ($ddnsMode = "interface") do={
            :local v4Id [/ip address find where interface=$waninterfacev4 disabled=no]
            :if ([:len $v4Id] > 0) do={
                :set ipv4fresh [/ip address get [:pick $v4Id 0] address]
            }
        } else={
            :do {
                :if ($ddnsMode = "nat") do={
                    :do {
                        /tool/fetch url=$ipv4URL mode=https dst-path="$ipv4file";
                        :delay 1000ms;
                        :local fileId [file find name="$ipv4file"];
                        :if ([:len $fileId] > 0) do={
                        :set ipv4fresh [file get [:pick $fileId 0] contents];
                        }
                    } on-error={
                        :log error "DDNS: Failed to fetch or read IPv4 file.";
                    }
                } else={
                    :log error ("DDNS: Invalid ddnsMode configured ('" . $ddnsMode . "'). Use 'interface' or 'nat'.");
                    :log error ("DDNS: ddns update stopped");
                    :exit;
                }
            }
        }

        #Address cleaning (mask stripping)
        :if ([:len $ipv4fresh] > 0) do={
            :for i from=( [:len $ipv4fresh] - 1) to=0 do={ 
                :if ([:pick $ipv4fresh $i ($i + 1)] = "/") do={ 
                    :set ipv4fresh [:pick $ipv4fresh 0 $i];
                } 
            }
        }

        :if ($ipv4fresh = "" || [:typeof $ipv4fresh] = nil) do={
            :log error ("DDNS: Failed to acquire valid IPv4 address in mode '$ddnsMode'.")
            :set ipv4error true
        }
    } on-error={
        :log error "DDNS: An error occurred while resolving IPv4 address."
        :set ipv4error true
    }

    :do {
        :if ($ipv4error) do={
            :log warning "DDNS: Skipping IPv4 update due to previous error."
        } else={
            :if ($ipv4ddns = $ipv4fresh) do={
                :log info ("DDNS: IPv4 address is already up to date.")
            } else {
                :log info ("DDNS: IPv4 address has changed from $ipv4ddns to $ipv4fresh, sending update...")
                :local body "hostname=$ddnshost&password=$ddnspass&myip=$ipv4fresh"
                :local result [/tool fetch mode=https output=user url=$updateURL http-method=post http-data=$body as-value]
                :if ($result->"status" != "finished") do={
                    :log error ("DDNS: Failed to send IPv4 update.")
                } else {
                    :log info ("DDNS: Response from server: " . $result->"data")
                    :if ([:find ($result->"data") "good"] >= 0 || [:find ($result->"data") "nochg"] = 0) do={
                        :set ipv4ddns $ipv4fresh
                    }
                }
            }
        }
    } on-error={
        :log error "DDNS: An error occurred while updating IPv4."
    }
}

# --- IPv6 query & refresh ---
:if ($enableIpv6) do={
    :do {
        :local v6Ids [/ipv6/address find where interface=$waninterfacev6]
        :foreach id in=$v6Ids do={
            :local addr [/ipv6/address get $id address]
            :if ([:pick $addr 0 4] != "fe80") do={
                :set ipv6fresh $addr
            }
        }
        
        :if ([:len $ipv6fresh] > 0) do={
            :for i from=( [:len $ipv6fresh] - 1) to=0 do={ 
                :if ([:pick $ipv6fresh $i ($i + 1)] = "/") do={ 
                    :set ipv6fresh [:pick $ipv6fresh 0 $i];
                } 
            }
        }

        :if ($ipv6fresh = "" || [:typeof $ipv6fresh] = nil) do={
            :log error ("DDNS: Failed to acquire valid IPv6 address from $waninterfacev6.")
            :set ipv6error true
        }
    } on-error={
        :log error "DDNS: An error occurred while resolving IPv6 address."
        :set ipv6error true
    }

    :do {
        :if ($ipv6error) do={
            :log warning "DDNS: Skipping IPv6 update due to previous error."
        } else={
            :if ($ipv6ddns = $ipv6fresh) do={
                :log info ("DDNS: IPv6 address is already up to date.")
            } else {
                :log info ("DDNS: IPv6 address has changed from $ipv6ddns to $ipv6fresh, sending update...")
                :local body "hostname=$ddnshost&password=$ddnspass&myip=$ipv6fresh"
                :local result [/tool fetch mode=https output=user url=$updateURL http-method=post http-data=$body as-value]
                :if ($result->"status" != "finished") do={
                    :log error ("DDNS: Failed to send IPv6 update.")
                } else {
                    :log info ("DDNS: Response from server: " . $result->"data")
                    :if ([:find ($result->"data") "good"] = 0 || [:find ($result->"data") "nochg"] = 0) do={
                        :set ipv6ddns $ipv6fresh
                    }
                }
            }
        }
    } on-error={
        :log error "DDNS: An error occurred while updating IPv6."
    }
}
