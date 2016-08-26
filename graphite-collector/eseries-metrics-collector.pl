#!/usr/bin/perl

#
# Copyright 2016 Pablo Luis Zorzoli
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

use strict;
use warnings;
use LWP::UserAgent;
use Data::Dumper;
use MIME::Base64;
use JSON;
use Config::Tiny;
use Getopt::Std;
use Benchmark;
use Sys::Syslog;
use Scalar::Util qw(looks_like_number);

my $DEBUG            = 0;
my $api_ver          = '/devmgr/v2';
my $API_TIMEOUT      = 15;
my $PUSH_TO_GRAPHITE = 1;

# Selected metrics to collect from any Volume, for ease of reading keep sorted
my %vol_metrics = (
    'averageReadOpSize'          => 0,
    'averageWriteOpSize'         => 0,
    'combinedIOps'               => 0,
    'combinedResponseTime'       => 0,
    'combinedThroughput'         => 0,
    'flashCacheHitPct'           => 0,
    'flashCacheReadHitBytes'     => 0,
    'flashCacheReadHitOps'       => 0,
    'flashCacheReadResponseTime' => 0,
    'flashCacheReadThroughput'   => 0,
    'otherIOps'                  => 0,
    'queueDepthMax'              => 0,
    'queueDepthTotal'            => 0,
    'readCacheUtilization'       => 0,
    'readHitBytes'               => 0,
    'readHitOps'                 => 0,
    'readIOps'                   => 0,
    'readOps'                    => 0,
    'readPhysicalIOps'           => 0,
    'readResponseTime'           => 0,
    'readThroughput'             => 0,
    'writeCacheUtilization'      => 0,
    'writeHitBytes'              => 0,
    'writeHitOps'                => 0,
    'writeIOps'                  => 0,
    'writeOps'                   => 0,
    'writePhysicalIOps'          => 0,
    'writeResponseTime'          => 0,
    'writeThroughput'            => 0,
);
# Selected metrics to collect from any drive, for ease of reading keep sorted.
my %drive_metrics = (
    'averageReadOpSize'     => 0,
    'averageWriteOpSize'    => 0,
    'combinedIOps'          => 0,
    'combinedResponseTime'  => 0,
    'combinedThroughput'    => 0,
    'otherIOps'             => 0,
    'readIOps'              => 0,
    'readOps'               => 0,
    'readPhysicalIOps'      => 0,
    'readResponseTime'      => 0,
    'readThroughput'        => 0,
    'writeIOps'             => 0,
    'writeOps'              => 0,
    'writePhysicalIOps'     => 0,
    'writeResponseTime'     => 0,
    'writeThroughput'       => 0,
);

my $metrics_collected;
my $system_id;

# Send our output to rsyslog.
openlog( 'eseries-metrics-collector', 'pid', 'local0' );

# Command line opts parsing and processing.
my %opts = ( h => undef );
getopts( 'hdnc:t:i:', \%opts );

if ( $opts{'h'} ) {
    print "Usage: $0 [options]\n";
    print "  -h: This help message.\n";
    print "  -n: Don't push to graphite.\n";
    print "  -d: Debug mode, increase verbosity.\n";
    print "  -c: Webservice proxy config file.\n";
    print "  -t: Timeout in secs for API Calls (Default=$API_TIMEOUT).\n";
    print "  -i: E-Series ID to Poll. ID is bound to proxy instance.\n";
    print "      If not defined use all appliances known by Proxy.\n";

    exit 0;
}
if ( $opts{'d'} ) {
    $DEBUG = 1;
    logPrint("Executing in DEBUG mode, enjoy the verbosity :)");
}
if ( $opts{'c'} ) {
    if ( not -e -f -r $opts{'c'} ) {
        warn "Access problems to $opts{'c'} - check path and permissions.\n";
        exit 1;
    }
}
else {
    warn "Need to define a webservice proxy config file.\n";
    exit 1;
}
if ( $opts{'i'} ) {
    $system_id = $opts{'i'};
    logPrint("Will only poll -$system_id-");
}
else {
    logPrint("Will poll all known systems by Webservice proxy.");
}
if ( $opts{'n'} ) {
    # unset this, as user defined to not send metrics to graphite.
    $PUSH_TO_GRAPHITE = 0;
    logPrint("User decided to not push metrics to graphite.");
}
if ( $opts{'t'} ) {
    if ( looks_like_number($opts{'t'}) ){
        $API_TIMEOUT = $opts{'t'};
        logPrint("Redefined timeout to $API_TIMEOUT seconds");
    }
    else {
        warn "Timeout ($opts{'t'}) is not a valid number. Using default.\n";
    }
}


my $config = Config::Tiny->new;
$config = Config::Tiny->read( $opts{'c'} );

my $username = $config->{_}->{user};
my $password = $config->{_}->{password};
my $base_url
    = $config->{_}->{proto} . '://'
    . $config->{_}->{proxy} . ':'
    . $config->{_}->{port};

logPrint("Base URL for Statistics Collection=$base_url") if $DEBUG;

my $ua = LWP::UserAgent->new;
$ua->timeout($API_TIMEOUT);

$ua->default_header( 'Content-type', 'application/json' );
$ua->default_header( 'Accept',       'application/json' );
$ua->default_header( 'Authorization',
    'Basic ' . encode_base64( $username . ':' . $password ) );
my $t0 = Benchmark->new;

my $response;
if ($system_id) {
    logPrint("API: Calling storage-systems/{system-id} ...");
    $response
        = $ua->get( $base_url . $api_ver . '/storage-systems/' . $system_id );
}
else {
    logPrint("API: Calling storage-systems...");
    $response = $ua->get( $base_url . $api_ver . '/storage-systems' );
}
my $t1 = Benchmark->new;
my $td = timediff( $t1, $t0 );
logPrint( "API: Call took " . timestr($td) );

if ( $response->is_success ) {
    my $storage_systems = from_json( $response->decoded_content );

    print Dumper( \$storage_systems ) if $DEBUG;
    if ($system_id) {

        # When polling only one system we get a Hash.
        my $stg_sys_name = $storage_systems->{name};
        my $stg_sys_id   = $storage_systems->{id};

        logPrint("Processing $stg_sys_name ($stg_sys_id)");

        $metrics_collected->{$stg_sys_name} = {};

        get_vol_stats( $stg_sys_name, $stg_sys_id, $metrics_collected );
        get_drive_stats( $stg_sys_name, $stg_sys_id, $metrics_collected );
    }
    else {

        # All systems polled, we get an array of hashes.
        for my $stg_sys (@$storage_systems) {
            my $stg_sys_name = $stg_sys->{name};
            my $stg_sys_id   = $stg_sys->{id};

            logPrint("Processing $stg_sys_name ($stg_sys_id)");

            $metrics_collected->{$stg_sys_name} = {};

            get_vol_stats( $stg_sys_name, $stg_sys_id, $metrics_collected );
            get_drive_stats( $stg_sys_name, $stg_sys_id, $metrics_collected );
        }
    }
}
else {
    if ( $response->code eq '404' ) {
        warn "The SystemID: ".$system_id .", was not found on the proxy.\n";
        warn "Please check the documentation on how to search for it.\n";
    }
    else {
        die $response->status_line;
    }
}

print "Metrics Collected: \n " . Dumper( \$metrics_collected ) if $DEBUG;
if ( $PUSH_TO_GRAPHITE ) {
    post_to_graphite($metrics_collected);
}
else {
    logPrint("No metrics sent to graphite. Remove the -n if this was not intended.");
}

logPrint('Execution completed');
exit 0;

# Utility sub to send info to rsyslog and STDERR if in debug mode.
sub logPrint {
    my $text = shift;
    my $level = shift || 'info';

    if ($text) {
        syslog( $level, $text );
        $DEBUG && warn $level . ' ' . $text . "\n";
    }
}

# Invoke remote API to get per volume statistics.
sub get_vol_stats {
    my ( $sys_name, $sys_id, $met_coll ) = (@_);

    my $t0 = Benchmark->new;
    logPrint("API: Calling analysed-volume-statistics");
    my $stats_response
        = $ua->get( $base_url 
            . $api_ver
            . '/storage-systems/'
            . $sys_id
            . '/analysed-volume-statistics' );
    my $t1 = Benchmark->new;
    my $td = timediff( $t1, $t0 );
    logPrint( "API: Call took " . timestr($td) );
    if ( $stats_response->is_success ) {
        my $vol_stats = from_json( $stats_response->decoded_content );
        logPrint( "get_vol_stats: Number of vols: " . scalar(@$vol_stats) );

        # skip if no vols present on this system
        if ( scalar(@$vol_stats) ) {
            process_vol_metrics( $sys_name, $vol_stats, $metrics_collected );
        }
        else {
            warn "Not processing $sys_name because it has no Volumes\n"
                if $DEBUG;
        }
    }
    else {
        die $stats_response->status_line;
    }
}

# Coalece Collecter metrics into custom structure, to just store the ones
# we care about.
sub process_vol_metrics {
    my ( $sys_name, $vol_mets, $met_coll ) = (@_);

    for my $vol (@$vol_mets) {
        my $vol_name = $vol->{volumeName};
        logPrint( "process_vol_metrics: Volume Name " . $vol_name ) if $DEBUG;
        my $vol_met_key = "volume_statistics.$vol_name";
        $metrics_collected->{$sys_name}->{$vol_met_key} = {};

        #print Dumper($vol);
        foreach my $met_name ( keys %{$vol} ) {

            #print "Met name = $met_name\n";
            if ( exists $vol_metrics{$met_name} ) {
                $met_coll->{$sys_name}->{$vol_met_key}->{$met_name}
                    = $vol->{$met_name};
            }
        }
    }
}

# Manage Sending the metrics to Graphite Instance
sub post_to_graphite {
    my ($met_coll)          = (@_);
    my $local_relay_timeout = $config->{'graphite'}->{'timeout'};
    my $local_relay_server  = $config->{'graphite'}->{'server'};
    my $local_relay_port    = $config->{'graphite'}->{'port'};
    my $metrics_path        = $config->{'graphite'}->{'root'};
    my $local_relay_proto   = $config->{'graphite'}->{'proto'};
    my $epoch               = time();
    my $full_metric;

    my $socket_err;
    logPrint("post_to_graphite: Issuing new socket connect.") if $DEBUG;
    my $connection = IO::Socket::INET->new(
        PeerAddr => $local_relay_server,
        PeerPort => $local_relay_port,
        Timeout  => $local_relay_timeout,
        Proto    => $local_relay_proto,
    );

    if ( !defined $connection ) {
        $socket_err = $! || 'failed without a specific library error';
        logPrint(
            "post_to_graphite: New socket connect failure with reason: [$socket_err]",
            "err"
        );
    }

    # Send metrics and upon error fail fast
    foreach my $system ( keys %$met_coll ) {
        logPrint("post_to_graphite: Build Metrics for -$system-") if $DEBUG;
        foreach my $vols ( keys $met_coll->{$system} ) {
            logPrint("post_to_graphite: Build Metrics for vol -$vols-") if $DEBUG;
            foreach my $mets ( keys $met_coll->{$system}->{$vols} ) {
                $full_metric
                    = $metrics_path
                    . "."
                    . $system
                    . "."
                    . $vols . "."
                    . $mets . " "
                    . $met_coll->{$system}->{$vols}->{$mets} . " "
                    . $epoch;
                logPrint( "post_to_graphite: Metric: " . $full_metric ) if $DEBUG;

                if ( ! defined $connection->send("$full_metric\n") ){
                    $socket_err = $! || 'failed without a specific library error';
                    logPrint("post_to_graphite: Socket failure with reason: [$socket_err]",  "err" );
                    undef $connection;
                }
            }
        }
    }
}

# Invoke remote API to get per drive statistics.
sub get_drive_stats {
    my ( $sys_name, $sys_id, $met_coll ) = (@_);

    my $t0 = Benchmark->new;
    logPrint("API: Calling analysed-drive-statistics");
    my $stats_response
        = $ua->get( $base_url
            . $api_ver
            . '/storage-systems/'
            . $sys_id
            . '/analysed-drive-statistics' );
    my $t1 = Benchmark->new;
    my $td = timediff( $t1, $t0 );
    logPrint( "API: Call took " . timestr($td) );
    if ( $stats_response->is_success ) {
        my $drive_stats = from_json( $stats_response->decoded_content );
        logPrint( "get_drive_stats: Number of drives: " . scalar(@$drive_stats) );

        # skip if no drives present on this system (really possible?)
        if ( scalar(@$drive_stats) ) {
            process_drive_metrics( $sys_name, $drive_stats, $metrics_collected );
        }
        else {
            warn "Not processing $sys_name because it has no Drives\n"
                if $DEBUG;
        }
    }
    else {
        die $stats_response->status_line;
    }
}

# Coalece Drive metrics into custom structure, to just store the ones
# we care about.
sub process_drive_metrics {
    my ( $sys_name, $drv_mets, $met_coll ) = (@_);

    for my $drv (@$drv_mets) {
        my $disk_id = $drv->{diskId};
        logPrint( "process_drive_metrics: DiskID " . $disk_id ) if $DEBUG;
        my $drv_met_key = "drive_statistics.$disk_id";
        $metrics_collected->{$sys_name}->{$drv_met_key} = {};

        #print Dumper($drv);
        foreach my $met_name ( keys %{$drv} ) {

            if ( exists $drive_metrics{$met_name} ) {
                $met_coll->{$sys_name}->{$drv_met_key}->{$met_name}
                    = $drv->{$met_name};
            }
        }
    }
}
