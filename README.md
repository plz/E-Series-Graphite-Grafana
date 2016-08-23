# NetApp E-Series Graphite and Grafana Integration
Collect Metrics from NetApp E-Series Storage appliances and dispatch them to graphite.

This repository contains a perl script that can connect to the NetApp Santricity web
proxy, and collect performance metrics from a E-Series Storage Appliance.
You can also use the Grafana Dashboard provided to visualize the collected metrics.

Data Collection
--------------------------------------------------------------------------------
* `graphite-collector/eseries-metrics-collector.pl` - Script that will connect
   to the web proxy and collect data, and pushes it to graphite. You'll need
   a functioning web proxy as requisite.

Data Visualization
--------------------------------------------------------------------------------
* `grafana-dashboards/Overview.json` - Import this dashboard and visualize the 
   collected metrics.

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
Although the steps to configure the Santricity Web Services Proxy is out of scope
there are 2 important configuration settings you need to define in wsconfig.xml

* `<env key="stats.poll.interval">60</env>`
* `<env key="stats.poll.save.history">1</env>`

If you need extra details on how to work with the proxy, you might want to check
the [User Guide](https://library.netapp.com/ecm/ecm_get_file/ECMLP2428357). This
link requires access to NetApp support site.

Data Collection Script Usage
-------------------------------------------------------------------------------
Script is meant to be run under crontab every minute. 

./eseries-metrics-collector.pl -h
Usage: ./eseries-metrics-collector.pl [options]

* `-h`: This help message.
* `-n`: Don't push to graphite.
* `-d`: Debug mode, increase verbosity.
* `-c`: Webservice proxy config file.
* `-t`: Timeout in seconds for API Calls (Default=15).
* `-i`: E-Series ID to Poll. ID is bound to proxy instance. If not defined use all appliances known by Proxy.

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


Contact
--------------------------------------------------------------------------------
**Project website**: https://github.com/plz/E-Series-Graphite-Grafana

**Author**: Pablo Zorzoli <pablozorzoli@gmail.com>
