#!/usr/bin/php
<?php
/**
 * @brief stat UA in access log
 *
 * @author tlanyan<tlanyan@hotmail.com>
 * @link http://tlanyan.me
 */
/* vim: set ts=4; set sw=4; set ss=4; set expandtab; */

function getFileList(string $path) : array {
    return glob(rtrim($path, "/") . "/*access.log*");
}

function statFiles(array $files) : array {
    $stat = [];
    echo PHP_EOL, "start to read files...", PHP_EOL;
    foreach ($files as $file) {
        echo "read file: $file ...", PHP_EOL;
        $contents = getFileContent($file);
        foreach ($contents as $line) {
            $ua = getUA($line);
            if (isset($stat[$ua])) {
                $stat[$ua] += 1;
            } else {
                $stat[$ua] = 1;
            }
        }
    }
    echo "stat all files done!", PHP_EOL, PHP_EOL;
    return $stat;
}

function getFileContent(string $file) : array {
    if (substr($file, -3, 3) === ".gz") {
        return gzfile($file);
    }
    return file($file);
}

function getUA(string $line) : ?string {
    // important! Nginx log format determins the UA location in the line!
    // You may have to refactor following codes to get the right result
    // UA starts from fifth double quote 
    $count = 0;  $offset = 0;
    while ($count < 5) {
        $pos = strpos($line, '"', $offset);
        if ($pos === false) {
            echo "Error! Unknown line: $line", PHP_EOL;
            return null;
        }

        $count ++;
        $offset = $pos + 1;
    }

    $end = strpos($line, '"', $offset);
    return substr($line, $offset, $end - $offset);
}

function usage() {
    echo "Usage: php statUA.php [option] [dir]", PHP_EOL;
    echo "  options:", PHP_EOL;
    echo "    -h: show this help", PHP_EOL;
    echo "    -v: verbose mode", PHP_EOL;
    echo "-n NUM: UA list number", PHP_EOL;
    echo "   dir: directory to the log files", PHP_EOL;
    echo PHP_EOL;
}

function filterUA(array& $stat, array $UAFilters) {
    $filterCount = 0;
    foreach ($UAFilters as $filter) {
        foreach ($stat as $ua => $count) {
            if (stripos($ua, $filter) !== false) {
                $filterCount += $count;
                unset($stat[$ua]);
            }
        }
    }
    echo "filter $filterCount records!", PHP_EOL;
}

function printCount(array $stat) {
    $sum = array_sum($stat);
    foreach ($stat as $key => $count) {
        echo $key, " : ", $count, ", percent: ", sprintf("%.2f", 100*$count/$sum), PHP_EOL;
    }
}

function statOS(array $UAs) : array {
    global $debug;
    echo PHP_EOL, "stat OS...", PHP_EOL;
    $os = ["Windows", "MacOS", "Linux", "Android", "iOS", "other"];
    $stat = array_fill_keys($os, 0);
    foreach ($UAs as $key => $count) {
        if (strpos($key, "Windows") !== false) {
            $stat["Windows"] += $count;
        } else if (strpos($key, "Macintosh") !== false) {
            $stat["MacOS"] += $count;
        // must deal Android first, then Linux
        } else if (strpos($key, "Android") !== false) {
            $stat["Android"] += $count;
        } else if (strpos($key, "Linux") !== false) {
            $stat["Linux"] += $count;
        } else if (strpos($key, "iPhone") !== false || strpos($key, "iOS") !== false || strpos($key, "like Mac OS") !== false || strpos($key, "Darwin") !== false) {
            $stat["iOS"] += $count;
        } else {
            if ($debug) {
                echo "other: $key, count: $count", PHP_EOL;
            }
            $stat["other"] += $count;
        }
    }

    return $stat;
}

function statBrowser(array $UAs) : array {
    global $debug;
    echo PHP_EOL, "stat brwoser...", PHP_EOL;
    $browsers = ["Chrome", "Firefox", "IE", "Safari", "Edge", "Opera", "other"];
    $stat = array_fill_keys($browsers, 0);
    foreach ($UAs as $key => $count) {
        if (strpos($key, "MSIE") !== false) {
            $stat["IE"] += $count;
        } else if (strpos($key, "Edge") !== false) {
            $stat["Edge"] += $count;
        } else if (strpos($key, "Firefox") !== false) {
            $stat["Firefox"] += $count;
        } else if (strpos($key, "OPR") !== false) {
            $stat["Opera"] += $count;
        // first Chrome, then Safari
        } else if (strpos($key, "Chrome") !== false) {
            $stat["Chrome"] += $count;
        } else if (strpos($key, "Safari") !== false) {
            $stat["Safari"] += $count;
        } else {
            if ($debug) {
                echo "other: $key, count: $count", PHP_EOL;
            }
            $stat["other"] += $count;
        }
    }

    return $stat;
}

function parseCmd() {
    global $debug, $num, $path, $argc, $argv;
    $optind = null;
    $options = getopt("hvn:", [], $optind);
    if ($argc > 2 && empty($options)) {
        usage();
        exit(1);
    }
    if (isset($options['h'])) {
        usage();
        exit(0);
    }
    if (isset($options['v'])) {
        $debug = true;
    }
    if (isset($options['n'])) {
        $num = intval($options['n']);
        if ($num <= 0) {
            $num = 10;
        }
    }
    if ($argc === 2 && empty($options)) {
        $path = $argv[1];
    }
    if ($argc > $optind) {
        $path = $argv[$optind];
    }
    if (!is_dir($path)) {
        echo "invalid directory: $path", PHP_EOL;
        exit(1);
    }

    if ($debug) {
        echo "num: $num", PHP_EOL;
        echo "verbose: ", var_export($debug, true), PHP_EOL;
        echo "path: $path", PHP_EOL;
    }
}

if (version_compare(PHP_VERSION, "7.1") < 0) {
    exit("scripts require PHP >=7.1");
}

$path = ".";
$debug = false;
$num = 10;

$UAFilters = [
    "spider",
    "bot",
    "wget",
    "curl",
];

parseCmd();

$files = getFileList($path);
if (empty($files)) {
    echo '"' . realpath($path) . '" does not contain access log files.', PHP_EOL;
    exit(0);
}
$allUA = statFiles($files);
if (empty($allUA)) {
    echo "no data", PHP_EOL;
    exit(0);
}

filterUA($allUA, $UAFilters);

// sort array with count
uasort($allUA, function ($a, $b) {
    return $b - $a;
});

if ($debug) {
    print_r($allUA);
}

echo PHP_EOL, "---- top $num UA ----", PHP_EOL;
printCount(array_slice($allUA, 0, $num));
echo "-------------------", PHP_EOL;

$os = statOS($allUA);
echo PHP_EOL, "os count:", PHP_EOL;
printCount($os);

$browser = statBrowser($allUA);
echo PHP_EOL, "browser count:", PHP_EOL;
printCount($browser);
