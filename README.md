# E-Series-Graphite-Grafana
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
   collected metrics

Contact
--------------------------------------------------------------------------------
**Project website**: https://github.com/plz/E-Series-Graphite-Grafana

**Author**: Pablo Zorzoli <pablozorzoli@gmail.com>
