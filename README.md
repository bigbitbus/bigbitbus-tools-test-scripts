# BigBitBus Test Scripts

This repository contains a scripts to collect system and performance
information. These scripts collect and upload this information to BigBitBus
servers, which will then analyze the uploaded information and present
informational reports based on the uploaded data. These reports can contain
comparisons with standard hardware and cloud providers so users can compare
their systems to other systems. Please see the important information in the
[Disclaimer](#disclaimers) section.

## How does it work?

The [script](cpu/bigbitbus-cpu-check.sh) can run on Redhat and its derivatives,
Ubuntu, and Amazon Linux. It broadly collects two types of information from via
the [script](cpu/bigbitbus-cpu-check.sh): system information such as CPU and
memory details, and CPU performance information. CPU performance is measured
using the [stressng tool](https://kernel.ubuntu.com/~cking/stress-ng/). It is
important that the test server be idle at the time of running the test for
accurate results, and to prevent the test from starving your server's workloads.

The script uploads data to the bigbitbus server at the end of the test runs,
where it is processed. The user can simply visit the provided URL to obtain
up-to-date comparison information about relative performance and pricing of
similar cloud VMs.

## <a name="disclaimers"></a>  Important Disclaimers

1. The service is free, however BigBitBus reserves the right to further process
   and analyze and utilize the uploaded system and performance data uploaded by
   multiple users. Please do not use this service if you have reservations about
   your system's data being processed and used by BigBitBus in this manner.

2. All the script code made available here by BigBitBus to generate the report
   is governed  by the [Apache 2.0 license](LICENSE.md).
