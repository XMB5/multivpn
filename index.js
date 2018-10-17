const path = require('path');
const childProcess = require('child_process');
const EventEmitter = require('events');
const readline = require('readline');
const http = require('http');
const https = require('https');

//each vpn needs it's own IP routing table and IP address
//we start at a random routing table number and increment it each time
let tableNum = 203711;
//we use IP addresses from 198.18.0.0/15, the internal benchmarking block (see rfc5735 section 3)
//because they are most likely unused
let ipOffset = 2718;

//first 17 bits of 198.18.0.0/15 IP addresses
const ip_198_18_0_0_decimal = 3323068416;

/**
 * Returns an empty IP routing table number
 * @returns {number}
 */
function getNewTableNum () {
    //javascript will only run one function at a time,
    //so tableNum is safe and predictable to use
    tableNum ++;
    return tableNum;
}

/**
 * Returns an unused IP address
 * @returns {string}
 */
function getUnusedIpAddress () {
    ipOffset ++;
    let ipnum = ip_198_18_0_0_decimal | ipOffset;
    return ((ipnum >> 24) & 255) + '.' + ((ipnum >> 16) & 255) + '.' + ((ipnum >> 8) & 255) + '.' + (ipnum & 255);
}

//some openvpn options can trigger scripts, and others are incompatible with options we need
//we cannot disable scripts because we need to run a route-up script
const unsafeOvpnOpts = ['script-security', 'auth-user-pass', 'setenv', 'verb', 'iproute', 'up', 'tls-verify',
    'ipchange', 'client-connect', 'route-up', 'route-pre-down', 'client-disconnect', 'down', 'learn-address',
    'auth-user-pass-verify'];

const routeUpPath = path.join(__dirname, 'route-up.sh');
const routeDownPath = path.join(__dirname, 'route-down.sh');

class OpenVPNSwitch extends EventEmitter {

    constructor(ovpn, userpassFile) {

        super();

        this.tableNum = getNewTableNum();
        this.deviceIp = getUnusedIpAddress();

        //change the ovpn file into command line arguments
        this.cmdlineArgs = [
            '--script-security', '2',
            '--route-up', routeUpPath,
            '--route-pre-down', routeDownPath,
            '--route-noexec',
            '--setenv', 'rt_table', this.tableNum,
            '--setenv', 'custom_local_address', this.deviceIp,
            '--auth-user-pass', userpassFile];

        ovpn.split(/[\r\n]+/).forEach(line => {
            let opts = line.split(' ');
            if (opts.length > 0) {
                //remove quotes from the option name for the security check
                opts[0] = opts[0].replace('"', '').replace('\'', '');
                if (!unsafeOvpnOpts.includes(opts[0])) {
                    opts[0] = '--' + opts[0];
                    this.cmdlineArgs.push(...opts);
                }
            }
        });

    }

    start() {

        this.child = childProcess.spawn('openvpn', this.cmdlineArgs);
        this.childRunning = true;
        this.child.on('exit', () => {
            this.childRunning = false;
            this.emit('disconnect');
        });
        this.child.on('error', e => {
            this.emit('error', e);
        });
        readline.createInterface(this.child.stdout).on('line', line => {
            if (line.startsWith('route-up >')) {
                this.iptablesChanged = true;
                this.ifconfigLocal = /ifconfig_local: (\d+\.\d+\.\d+\.\d+) {2}ifconfig_remote: /.exec(line)[1];
            } else if (/^\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4} Initialization Sequence Completed$/.test(line)) {
                this.emit('connect');
            }
        });

    }

    stop () {

        if (this.childRunning) {
            this.child.kill('SIGINT');
        }

        if (this.iptablesChanged) {
            this.iptablesChanged = false;

            let iptablesChild = childProcess.spawn('iptables','-t', 'nat', '-D', 'POSTROUTING',
                '--source', this.deviceIp, '-j', 'SNAT', '--to-source', this.ifconfigLocal);

            iptablesChild.on('exit', code => {
                if (code !== 0) {
                    this.error('iptables reset command returned error code', code);
                }
            });
        }

    }

    getHttpAgent (secure) {

        let Agent = (secure ? https : http).Agent;
        let agent = new Agent({keepAlive: true});
        agent.createConnectionOriginal = agent.createConnection;
        agent.createConnection = function connect(opts, callback) {
            let optsCopy = Object.assign({}, opts);
            optsCopy.localAddress = this.deviceIp;
            return agent.createConnectionOriginal(optsCopy, callback);
        };

    }

}

module.exports = {OpenVPNSwitch};