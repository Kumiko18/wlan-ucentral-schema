{% if (!services.is_present("dhcpinject")) return %}
{% let ssids = services.lookup_ssids("dhcpinject") %}
{% let enable = length(ssids) %}
{% services.set_enabled("dhcpinject", enable) %}
{% if (!enable) return %}

# Dhcp Inject service configuration

set dhcpinject.ssids=ssids
{% for (let ssid in ssids): %}
add_list dhcpinject.ssids.ssid={{ s(ssid.name) }}
{% endfor %}