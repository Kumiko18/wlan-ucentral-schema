{%
	let fs = require('fs');

	// reject the config if there is no valid upstream configuration
	if (!state.uuid) {
		warn('Configuration must contain a valid UUID. Rejecting whole file');
		die('Configuration must contain a valid UUID. Rejecting whole file');
	}

	include('admin_ui.uc');

	// reject the config if there is no valid upstream configuration
	let upstream;
	for (let i, interface in state.interfaces) {
		if (interface.role != 'upstream')
			continue;
		upstream = interface;
	}

	if (!upstream) {
		warn('Configuration must contain at least one valid upstream interface. Rejecting whole file');
		die('Configuration must contain at least one valid upstream interface. Rejecting whole file');
	}


	for (let i, interface in state.interfaces)
		interface.index = i;

	/* find out which vlans are used and which should be assigned dynamically */
	let vlans = [];
	for (let i, interface in state.interfaces)
		if (ethernet.has_vlan(interface))
			push(vlans, interface.vlan.id);
		else
			interface.vlan = { id: 0};

	// populate the broad-band profile if present. This needs to happen after the default vlans 
	// and before the dynamic vlan are assigned
	let profile = local_profile.get();
	if (profile && profile.broadband)
		include('broadband.uc', { broadband: profile.broadband });

	let vid = 4090;
	function next_free_vid() {
		while (index(vlans, vid) >= 0)
			vid--;
		return vid--;
	}

	/* dynamically assign vlan ids to all interfaces that have none yet */
	for (let i, interface in state.interfaces)
		if (!interface.vlan.id)
			interface.vlan.dyn_id = next_free_vid();

	/* dynamically assign vlans to all swconfig ports */
	let swconfig = false;
	for (let k, port in ethernet.ports) {
		if (port.swconfig == null)
			continue;
		port.vlan = next_free_vid();
		port.switch = capab.switch_ports[port.netdev];
		port.netdev += '.' + port.vlan;
		swconfig = true;
	}

	if (swconfig) {
		ethernet.swconfig = {};
		for (let k, port in ethernet.ports) {
			if (!port.switch)
				continue;
			ethernet.swconfig[port.netdev] = port;
		}
	}

	include('base.uc');

	if (state.unit)
		include('unit.uc', { location: '/unit', unit: state.unit });

	if (!state.services)
                state.services = {};

	for (let service in services.lookup_services())
		tryinclude('services/' + service + '.uc', {
			location: '/services/' + service,
			[service]: state.services[service] || {}
		});

	if (!state.metrics)
		state.metrics = {};

	let file = fs.open('/etc/events.json', 'r');
	let events = [];
	if (file) {
		try {
			events = json(file.read('all'));
		} catch(e) {

		}
		file.close();
	}
	for (let metric in services.lookup_metrics())
		tryinclude('metric/' + metric + '.uc', {
			location: '/metric/' + metric,
			[metric]: state.metrics[metric] || {},
			events
		});

	if (state.switch)
		tryinclude('switch.uc', {
			location: '/switch/'
		});

	for (let i, ports in state.ethernet)
		include('ethernet.uc', { location: '/ethernet/' + i, ports });

	for (let i, radio in state.radios)
		include('radio.uc', { location: '/radios/' + i, radio });

	function iterate_interfaces(role) {
		for (let i, interface in state.interfaces) {
			if (interface.role != role)
				continue;
			include('interface.uc', { location: '/interfaces/' + i, interface, vlans });
		}
	}

	iterate_interfaces("upstream");
	iterate_interfaces("downstream");

	let fs = require('fs');
	for (let name in fs.glob('/usr/share/ucentral/templates/third-party/*.uc')) {
		name = split(fs.basename(name), '.')[0];
		let config = state.third_party ? state.third_party[name] : {};
		tryinclude('third-party/' + name + '.uc', {
			location: '/third-party/' + name,
			[replace(name, '-', '_')]: config
		});
	}
	services.set_enabled("usteer2", true);

	include('spotfilter.uc');

	if (state.config_raw)
		include("config_raw.uc", { location: '/config_raw', config_raw: state.config_raw });

	latency.write();
	services.set_enabled("bridger", false);
%}
