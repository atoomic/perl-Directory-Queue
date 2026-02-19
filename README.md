# Directory::Queue

[![CI](https://github.com/atoomic/perl-Directory-Queue/actions/workflows/ci.yml/badge.svg)](https://github.com/atoomic/perl-Directory-Queue/actions/workflows/ci.yml)
[![CPAN version](https://img.shields.io/cpan/v/Directory-Queue)](https://metacpan.org/pod/Directory::Queue)
[![License: Perl](https://img.shields.io/cpan/l/Directory-Queue)](https://dev.perl.org/licenses/)

Object oriented interface to a directory based queue.

## Overview

Directory::Queue provides a queue system using the filesystem for storage.
It uses atomic operations to prevent race conditions, making it safe for
multiple concurrent readers and writers without requiring an external daemon
or service.

**Key features:**

- Atomic operations via `link()`/`mkdir()` — no race conditions
- Multiple concurrent readers and writers on the same queue
- No external daemon required — pure filesystem
- Multiple queue types: simple (binary strings) or normal (structured schemas)
- Interoperable with [Python](https://github.com/cern-mig/python-dirq), [Java](https://github.com/cern-mig/java-dirq), and [C](https://github.com/cern-mig/c-dirq) implementations

## Installation

From CPAN:

```bash
cpanm Directory::Queue
```

Or manually:

```bash
perl Makefile.PL
make
make test
make install
```

### Dependencies

- [No::Worries](https://metacpan.org/pod/No::Worries) (>= 1.4)
- [Encode](https://metacpan.org/pod/Encode)
- [POSIX](https://metacpan.org/pod/POSIX)
- [Time::HiRes](https://metacpan.org/pod/Time::HiRes)

## Quick Start

### Producer

```perl
use Directory::Queue;

my $dirq = Directory::Queue->new(path => "/tmp/myqueue");

foreach my $count (1 .. 100) {
    my $name = $dirq->add("element $count\n");
    printf("added element %d as %s\n", $count, $name);
}
```

### Consumer (single pass)

```perl
use Directory::Queue;

my $dirq = Directory::Queue->new(path => "/tmp/myqueue");

for (my $name = $dirq->first(); $name; $name = $dirq->next()) {
    next unless $dirq->lock($name);
    my $data = $dirq->get($name);
    print "got: $data";
    $dirq->remove($name);
}
```

### Looping consumer with purging

```perl
use Directory::Queue;

my $dirq = Directory::Queue->new(path => "/tmp/myqueue");

while (1) {
    sleep(1) unless $dirq->count();
    for (my $name = $dirq->first(); $name; $name = $dirq->next()) {
        next unless $dirq->lock($name);
        my $data = $dirq->get($name);
        # ... process $data ...
        $dirq->remove($name);
    }
    $dirq->purge();  # clean up stale locks and temp files
}
```

## Queue Types

| Type | Module | Use Case |
|------|--------|----------|
| **Simple** | [Directory::Queue::Simple](https://metacpan.org/pod/Directory::Queue::Simple) | Fast, lightweight — stores binary strings |
| **Normal** | [Directory::Queue::Normal](https://metacpan.org/pod/Directory::Queue::Normal) | Structured data with schemas (binary, string, table) |
| **Null** | [Directory::Queue::Null](https://metacpan.org/pod/Directory::Queue::Null) | Black hole — discards everything (useful for testing) |
| **Set** | [Directory::Queue::Set](https://metacpan.org/pod/Directory::Queue::Set) | Merge-iterate over multiple queues |

By default, `Directory::Queue->new(...)` creates a **Simple** queue. To use
a different type:

```perl
# Explicit type via the base class
my $dirq = Directory::Queue->new(path => "/tmp/q", type => "Normal");

# Or use the subclass directly
my $dirq = Directory::Queue::Normal->new(
    path   => "/tmp/q",
    schema => { body => "string", header => "table?" },
);
```

### Simple vs Normal

**Simple** queues are recommended for most use cases. They are faster, use
less disk space, and have a simpler API. Each element is a single binary
string stored in a file.

**Normal** queues support structured data via schemas. Each element is a
directory containing multiple files (one per schema field). Fields can be
binary strings, UTF-8 text strings, or key-value tables. This is useful when
elements need to carry metadata alongside their payload.

## Locking

The locking mechanism ensures safe concurrent access:

```perl
for (my $name = $dirq->first(); $name; $name = $dirq->next()) {
    next unless $dirq->lock($name);    # skip if already locked by another process
    my $data = $dirq->get($name);       # read (requires lock)
    # ... process $data ...
    $dirq->remove($name);              # remove (requires lock)
}
```

- `lock()` is permissive by default — returns false if the element is already
  locked, rather than dying
- `get()` and `remove()` require the element to be locked first
- If a process dies while holding a lock, `purge()` will clean up after
  `maxlock` seconds (default: 600)

## Constructor Options

Options common to Simple and Normal queues:

| Option | Default | Description |
|--------|---------|-------------|
| `path` | *(required)* | Queue toplevel directory |
| `umask` | process umask | Umask for created files and directories |
| `maxlock` | 600 | Maximum lock age in seconds before purge unlocks it |
| `maxtemp` | 300 | Maximum temp file age in seconds before purge removes it |
| `rndhex` | random 0-15 | Hex digit to reduce name collisions |

Additional options for Simple:

| Option | Default | Description |
|--------|---------|-------------|
| `granularity` | 60 | Time granularity (seconds) for intermediate directories |

Additional options for Normal:

| Option | Default | Description |
|--------|---------|-------------|
| `schema` | *(required for add/get)* | Hash defining the data structure |
| `maxelts` | 16000 | Maximum elements per intermediate directory |
| `nlink` | false | Use nlink optimization (faster, but not all filesystems) |

## FIFO Ordering

The queue provides **best-effort FIFO** ordering. Elements are named using
high-resolution timestamps, so they are very likely to be processed in
insertion order. However, with multiple concurrent writers, strict FIFO cannot
be guaranteed.

## Security

There are no specific security mechanisms in this module. The elements are
stored as plain files and directories. Use filesystem permissions (owner,
group, umask, ACLs) to protect the data.

For multi-user queues, set `umask => 0` so all files are world-writable, then
control access via the toplevel directory permissions.

## See Also

- [Directory::Queue::Simple](https://metacpan.org/pod/Directory::Queue::Simple) — simple queue implementation
- [Directory::Queue::Normal](https://metacpan.org/pod/Directory::Queue::Normal) — normal queue with schemas
- [Directory::Queue::Null](https://metacpan.org/pod/Directory::Queue::Null) — null queue (black hole)
- [Directory::Queue::Set](https://metacpan.org/pod/Directory::Queue::Set) — iterate over multiple queues
- [CPAN page](https://metacpan.org/pod/Directory::Queue)

## Contributing

Bug reports and pull requests are welcome on
[GitHub](https://github.com/atoomic/perl-Directory-Queue).

To run the test suite:

```bash
perl Makefile.PL
make
make test
```

## Authors

Originally written by Lionel Cons at [CERN](https://cern.ch/).

Currently maintained by [Nicolas R.](https://github.com/atoomic)

## License

This software is copyright (c) 2010 by CERN.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
