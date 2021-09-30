#!/usr/bin/perl
use strict;
use warnings;
use DateTime qw{};
use Net::MQTT::Simple qw{};
use RRD::Simple qw{};
use Path::Class qw{file dir};
use CGI qw{};
use JSON::XS qw{encode_json};
use List::MoreUtils qw{uniq};

local $|      = 1;
printf "%s: Start\n", DateTime->now;
my $host      = 'mqtt';
my $name      = 'mqtt-topic-grapher';
my $LWT       = "tele/$name/LWT";
my $topic     = 'grapher/+/#';
my $rrdpath   = "/var/$name";
my $htmlpath  = '/usr/share/mqtt-topic-grapher/html';
my $imgpath   = "$htmlpath/images";
my @durations = qw{4h 1d 1w 1y};
my $mqtt      = Net::MQTT::Simple->new($host);
my $rrd       = RRD::Simple->new;
my $htmlindex = 1;
my $cache     = {};

$mqtt->last_will($LWT => 'Offline');
$mqtt->retain($LWT => 'Online');
$mqtt->run($topic, \&handler);

printf "%s: Finish\n", DateTime->now;

sub handler {
  my $topic   = shift; #grapher/Temperature/basement
  my $value   = shift; #74.5
  my @parts   = split '/', $topic;
  my $epoch   = time;
  my $graph   = $parts[1];
  my $series  = $parts[2];
  $cache->{$graph}->{$series} = $value;
  my $rrdfile = "$rrdpath/grapher-$graph-$series.rrd";
  unless (-f $rrdfile) {
    create($rrdfile);
    $htmlindex = 1;
  }
  local $@;
  eval{$rrd->update($rrdfile, $epoch, dataset => $value)};
  my $error = $@;
  if ($error) {
    print "Error: ", $@;
  } else {
    graph({
           graph => $graph,
           value => $value,
           epoch => $epoch,
           cache => $cache,
          });
  }
  if ($htmlindex) {
    createhtml({});
    $htmlindex = 0;
  }
}

sub create {
  #every metric gets it own RRD file with a DS called "dataset"
  my $file = shift;
  die("Error: File $file exists.\n") if -f $file;
  my $cmd  = qq{/usr/bin/rrdtool create '$file' \\
                 --step '60' \\
                 --start '1613009830' \\
                 'DS:dataset:GAUGE:60:0:U' \\
                 'RRA:AVERAGE:0.5:1:5000' \\
                 'RRA:AVERAGE:0.5:15:5000' \\
                 'RRA:AVERAGE:0.5:240:5000' \\
                 'RRA:AVERAGE:0.5:720:5000' \\
               };

  print "$cmd\n";
  print qx{$cmd};
}

sub graph {
  #metrics with the same graph name are put on the same image
  my $env    = shift;
  my $graph  = $env->{'graph'};
  my $value  = $env->{'value'};
  my $epoch  = $env->{'epoch'};
  my $cache  = $env->{'cache'};
  my $title  = $graph;
  my $lower  = 0;
  my $upper  = 100;
  if ($graph =~ m/\A(?:[0-9]+_)?([^_]+)_([0-9]+)_([0-9]+)\Z/) { #200_Humidity_0_100 #sort title lower upper
    $title = $1;
    $lower = $2;
    $upper = $3;
  } elsif ($graph =~ m/\A(?:[0-9]+_)?([^_]+)\Z/) { #400_Power #sort title
    $title = $1;
  }
  my $dt     = DateTime->from_epoch(epoch=>$epoch);
  $title     = sprintf("%s (%s)", $title, $dt->strftime('%r'));
  my @colors = (
                "009d48", #green
                "2153c6", #blue
                "f1842b", #orange
                "ab4499", #purple 
                "fe5d9f", #red
                "ffd209", #yellow
               );
  my @def    = ();
  my @line   = ();
  my $loop   = 0;
  my @files  = sort (dir($rrdpath)->children);
  foreach my $file (@files) {
    my $basename = $file->basename;
    next unless $basename =~ m/\Agrapher-$graph-([^-]+).rrd\Z/;
    my $series   = $1;
    my $color    = $colors[$loop] || '000000';
    $loop++;
    my $value    = $cache->{$graph}->{$series};
    my $display  = defined($value) ? sprintf("%s (%s)", $series, $value) : $series;
    push @def, "'DEF:f$loop=$file:dataset:AVERAGE'";
    push @line, "'LINE2:f$loop#$color:$display'";
  }
  if (@def) {
    foreach my $duration (@durations) {
      my $out = "$imgpath/grapher-$graph-$duration.png";
      my @cmd = (
                 'rrdtool',  'graph',
                 $out,
                 '--title',  "'$title'",
                 '--width',  480,
                 '--height', 160,
                 '--start',  "end-$duration",
                 '--lower-limit', $lower,
                 '--upper-limit', $upper,
                 '--rigid',
                 @def,
                 @line
                );
      my $cmd = join " ", @cmd;
     #print "$cmd\n";
      qx{$cmd};
    }
  }
}

sub createhtml {
  my $env           = shift;
  my $loop          = 0;
  my @files         = sort (dir($rrdpath)->children);
  my @keys          = ();
  foreach my $file (@files) {
    my $basename = $file->basename;
    next unless $basename =~ m/\A(grapher-[^-]+)-[^-]+.rrd\Z/;
    push @keys, $1;
  }
  @keys = uniq @keys;
  my $cgi           = CGI->new("");
  my $graphs_json   = encode_json(\@keys);
  my $duration_json = encode_json([{type=>'4h', mod=>1}, {type=>'1d', mod=>3}, {type=>'1w', mod=>21}, {type=>'1y', mod=>21}]);
  my $onload        = "setInterval(setImages,20000);";
  my $filename      = "$htmlpath/index.html";
  my $javascript    = qq{
                        var iLoop      = 0; /* use an id to not cache requests between loops */
                        var aGraph     = JSON.parse('$graphs_json');
                        var aDurations = JSON.parse('$duration_json');
                        function setImages() {
                          iLoop++;
                          console.log("Loop: " + iLoop);
                          for (let oDuration of aDurations) {
                            if ( iLoop % oDuration['mod'] == 0 ) {
                              for (let sGraph of aGraph) {
                                var id = sGraph + "-" + oDuration['type'];
                                var src = "images/" + sGraph + "-" + oDuration['type'] + ".png" + "?i=" + iLoop;
                                document.getElementById(id).src = src;
                              }
                            }
                          }
                        }
                      };
  my $html          = join "",
                        $cgi->start_html(-title   => "Sensors",
                                         -bgcolor => "#FFFFFF",
                                         -script  => $javascript,
                                         -onload  => $onload,
                                        ),
                         $cgi->table({-border=>0,
                                      -bordercolor=>"#111111",
                                      -cellpadding=>0,
                                      -cellspacing=>0,
                                      -style=>"BORDER-COLLAPSE: collapse",
                                     },
                          $cgi->Tr([
                           $cgi->td({-align=>"center"}, ["4-Hour", "1-Day", "1-Week", "1-Year"]),
                            map {
                              my $key=$_;
                              join "",
                                map {
                                  my $duration=$_;
                                  $cgi->td(
                                    $cgi->img({-id=>"$key-$duration", -src=>"images/$key-$duration.png"}),
                                  )
                                } @durations
                            } @keys
                          ]),
                         ),
                        $cgi->end_html,
                        "\n";
  file($filename)->spew($html);
}
