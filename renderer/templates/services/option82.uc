{% if (!services.is_present("option82")) return %}
{% let ssids = services.lookup_ssids("option82") %}
{% let enable = length(ssids) %}
{% services.set_enabled("option82", enable) %}
{% if (!enable) return %}

# Option82 service configuration

set option82.ssids=ssids
{% for (let ssid in ssids): %}
add_list option82.ssids.ssid={{ s(ssid.name) }}
{% endfor %}