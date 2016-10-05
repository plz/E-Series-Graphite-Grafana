# NetApp E-Series Graphite and Grafana Integration
Collect Metrics from NetApp E-Series Storage appliances and dispatch them to graphite.

This repository contains a perl script that can connect to the NetApp Santricity web
proxy, and collect performance metrics from a E-Series Storage Appliance.
You can also use the Grafana Dashboard provided to visualize the collected metrics.

Data Collection
--------------------------------------------------------------------------------
* `graphite-collector/eseries-metrics-collector.pl` - Script that will connect
   to the web proxy and collect data, and pushes it to graphite. You'll need
   a functioning web proxy as pre-requisite.

The collection script has been running on several Linux Systems with the
following specs:

* CentOS release 6.7 (Final)
* Perl v5.18.2
* Santricity Web Services Proxy 1.4 (01.40.X000.0009)
* Grafana 3.0.4

Data Visualization
--------------------------------------------------------------------------------
* `grafana-dashboards/Overview.json` - Import this dashboard and visualize the 
   collected metrics. This dashboard was inspired and tries to keep the look &
   feel similar to the _Cluster Group_ dashboard done by
   [Chris Madden](https://github.com/dutchiechris) for
   [NetApp Harvest](http://blog.pkiwi.com/category/netapp-harvest/).

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
Although the steps required to configure the Santricity Web Services Proxy are
out of scope for this guide, there are 2 important configuration settings you
need to define in *wsconfig.xml*

* `<env key="stats.poll.interval">60</env>`
* `<env key="stats.poll.save.history">1</env>`

If you need extra details on how to work with the proxy, you might want to check
the [User Guide](https://library.netapp.com/ecm/ecm_get_file/ECMLP2428357). This
link requires access to NetApp support site.

Data Collection Script Usage
-------------------------------------------------------------------------------
Script is meant to be scheduled under crontab every minute.

./eseries-metrics-collector.pl -h
Usage: ./eseries-metrics-collector.pl [options]

* `-h`: This help message.
* `-n`: Don't push to graphite.
* `-d`: Debug mode, increase verbosity.
* `-c`: Webservice proxy config file.
* `-t`: Timeout in seconds for API Calls (Default=15).
* `-i`: E-Series ID or System Name to Poll. ID is bound to proxy instance. If not defined it will use all appliances known by Proxy.

The recommended mechanisim is System Name, but if you want to use the System ID and you are not familiar with it, you can go to your console and execute the following:

    curl -X GET --header "Accept: application/json" "http://myproxy.example.com:8080/devmgr/v2/storage-systems" -u ro

And you should obtain something like:

    "id":"0e8bf25f-247d-4f87-97f3-xxxxxxxxxx",

Data Collection Script Configuration File
-------------------------------------------------------------------------------
The data collection script will need a configuration file with details on how
to connect to the proxy. Check `graphite-collector/proxy-config.conf` or 
the following snippet:

    ###
    ### Santricity Web Services Proxy hostname, FQDN, or IP
    ###
    proxy = mywebservice.example.com

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
