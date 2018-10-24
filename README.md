# NetApp E-Series Graphite and Grafana Integration
Collect Metrics from NetApp E-Series Storage appliances and dispatch them to graphite.

This repository contains a perl script that can connect to the NetApp Santricity web
proxy, and collect performance metrics from a E-Series Storage Appliance.

It's also possible to use the tool to monitor E-Series systems that run SANtricity
System Manager, that is the embedded management application & REST API.

You can also use the Grafana Dashboards provided to visualize the collected metrics.

Data Collection
--------------------------------------------------------------------------------
* `graphite-collector/eseries-metrics-collector.pl` - Script that will connect
   to the netapp webproxy or the embedded rest API (e2800) collect data, and push
   it to graphite. You might need a functioning web proxy as pre-requisite.

The collection script has been running on several Linux Systems with the
following specs:

* CentOS release 7.5.1804
* Perl v5.18.2
* Santricity Web Services Proxy 2.1 (02.10.7000.0008)
* Grafana 4.1.1
* SANtricity 11.40.2 on Embedded versions (e2800)

Data Visualization
--------------------------------------------------------------------------------
* `grafana-dashboards/Overview.json` - Import this dashboard and visualize the 
   collected metrics. This dashboard was inspired and tries to keep the look &
   feel similar to the _Cluster Group_ dashboard done by
   [Chris Madden](https://github.com/dutchiechris) for
   [NetApp Harvest](http://blog.pkiwi.com/category/netapp-harvest/).
* `grafana-dashboards/Disk Overview.json` - This is a Work-in-progress
   dashboard. It is used to represent per Disk Metrics exposed by proxy.
* `grafana-dashboards/Volume Detail.json` - It is used to represent per
   volume metrics.

Perl Dependencies
-------------------------------------------------------------------------------
* LWP::UserAgent
* MIME::Base64
* JSON
* Config::Tiny
* Benchmark
* Scalar::Util

Setting up the Web Proxy
-------------------------------------------------------------------------------
The need of a Web Proxy instance will depend on the E-Series model you are
trying to monitor. E2800 and other newer models already ship SANtricity System
Manager which replace the features that the proxy used to provide.

Although the steps required to configure the Santricity Web Services Proxy are
out of scope for this guide, there are 2 important configuration settings you
need to define in *wsconfig.xml*

* `<env key="stats.poll.interval">60</env>`
* `<env key="stats.poll.save.history">1</env>`

If you need extra details on how to work with the proxy, you might want to check
the [User Guide](https://library.netapp.com/ecm/ecm_download_file/ECMLP2524838). This
link requires access to NetApp support site.

Data Collection Script Configuration File
-------------------------------------------------------------------------------
The data collection script will need a configuration file with details on how
to connect to the appliance. Check `graphite-collector/api-config.conf` or
the following snippet  for inspiration:

    ###
    ### Santricity Web Services Proxy hostname, FQDN, or IP
    ### If monitoring a system with embedded management interface use that FQDN.
    ###
    restapi = mywebservice.example.com

    ###
    ### Protocol (http|https)
    ###
    proto = http

    ###
    ### TCP Port
    ###
    ###   - Default is 8080 for HTTP
    ###   - Default is 8443 for HTTPS
    ###
    port = 8080

    ###
    ### User and password to connect with
    ###
    user        = ro
    password    = XXXXXXXXXXXXXXX

    ###
    ### Graphite Details
    ###
    [graphite]
    server      = localhost
    port        = 3002
    proto       = tcp
    root        = storage.eseries
    timeout     = 5

Network Connectivity Requirements
-------------------------------------------------------------------------------
Once you define the configuration file based on the above section, you'll already
have a clear picture of the connectivity requirements for the script to be able
to work properly:

1. restapi & port: Based on that configuration pair, you know that you'll need
to review any firewalls in the middle between the place were you run collection
script and the actual storage appliance.

2. graphite server & port: This may also vary a lot depending on your graphite
setup, but in order to be able to ship metrics, you'll need to be able to access
either your graphite instance directly, or a submission relay of sorts.

Entries in syslog should warn you about failures to connnect to an endpoint:

    2018-10-23T17:20:07.840014+02:00 myhostname eseries-metrics-collector[34674]: Request FAILED: 500 Can't connect to eseriesXX1.xxx.example.com:443

Data Collection Script Usage
-------------------------------------------------------------------------------
The collection script can be deployed in 2 different ways:

Option 1: _Cron_

The simpler, via cron job every minute. As an inspiration for you:

    * * * * *  mycronuser  /opt/netapp/eseries-graphite-collector/eseries-metrics-collector.pl -c /opt/netapp/eseries-graphite-collector/conf/api-config.conf -i my-eseries-system-001 -e

Option 2: _SystemD Service_

Alternatively, you can use the systemd unit file provided by Maulis Adam <maulis@andrews.hu> which lives in the misc directory `eseries-metrics-collector.service`. The script assumes you have installed the collector in /opt/netapp/E-Series-Graphite-Grafana. If that's not the case *you* will need to tweak it.

    systemctl enable /opt/netapp/E-Series-Graphite-Grafana/eseries-metrics-collector.service
    systemctl start eseries-metrics-collector

These are the command line arguments that can be used to modify the behavior of the collector.
./eseries-metrics-collector.pl -h
Usage: ./eseries-metrics-collector.pl [options]

* `-h`: This help message.
* `-n`: Don't push to graphite.
* `-d`: Debug mode, increase verbosity.
* `-c`: config file with credentials and API End Point.
* `-t`: Timeout in seconds for API Calls (Default=15).
* `-i`: E-Series ID or System Name to Poll. ID is bound to proxy instance. If not defined it will use all appliances known by Proxy.
* `-e`: Flag for embedded mode. Option applicable for systems running API services in-box

The recommended mechanism to specify the system to monitor is System Name, but if you want to use the System ID and you are not familiar with it, you can go to your console and execute the following:

    curl -X GET --header "Accept: application/json" "http://myproxy.example.com:8080/devmgr/v2/storage-systems" -u ro

And you should obtain something like:

    "id":"0e8bf25f-247d-4f87-97f3-xxxxxxxxxx",

Docker
--------------------------------------------------------------------------------
A Dockerfile and Docker-Compose file are available for simple deployment and/or trying out the functionality.

The Dockerfile is intended to be a simple deployment of this project only, and is most useful if you
already have Graphite and Grafana installed separately. If neither are currently installed/running, the
docker-compose.yml file will define a test configuration for you that will start all three.

It will be necessary for you to modify the graphite-collector/api-config.conf file with details on your
environment, including the location and credentials of the WebServices Proxy, etc.

Grafana will not load the dashboards provided in grafana-dashboards by default. These may be imported
into the running Grafana instance. They will be persisted by default in a mount Docker host volume.

BUGS
--------------------------------------------------------------------------------
Please report them [here](https://github.com/plz/E-Series-Graphite-Grafana/issues)

TODO
--------------------------------------------------------------------------------
This tool is a work in progress, and many features are yet missing in order to
become something like [NetApp Harvest](http://blog.pkiwi.com/category/netapp-harvest/) for FAS Systems.

Contributions are welcome, and these are some of the topics that are in the TODO
list:

* Include per disk metrics.[Issue1](https://github.com/plz/E-Series-Graphite-Grafana/issues/1)
* Include metrics on the collection itself (timings) [Issue3](https://github.com/plz/E-Series-Graphite-Grafana/issues/3)

Contact
--------------------------------------------------------------------------------
**Project website**: https://github.com/plz/E-Series-Graphite-Grafana

**Author**: Pablo Zorzoli <pablozorzoli@gmail.com>
