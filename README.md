# NAME

Directory::Queue - Object oriented interface to a directory based queue

# VERSION

version 2.3

# SYNOPSIS

```perl
use Directory::Queue;

#
# sample producer
#

my $dirq = Directory::Queue->new(path => "/tmp/test");
foreach my $count (1 .. 100) {
    my $name = $dirq->add(<<'EOS');
  ... some data ...
  EOS
    printf("# added element %d as %s\n", $count, $name);
}

#
# sample consumer (one pass only)
#

$dirq = Directory::Queue->new(path => "/tmp/test");
for (my $name = $dirq->first(); $name; $name = $dirq->next()) {
    next unless $dirq->lock($name);
    printf("# reading element %s\n", $name);
    my $data = $dirq->get($name);
    # one could use $dirq->unlock($name) to only browse the queue...
    $dirq->remove($name);
}
```

# DESCRIPTION

The goal of this module is to offer a queue system using the underlying
filesystem for storage, security and to prevent race conditions via atomic
operations. It focuses on simplicity, robustness and scalability.

This module allows multiple concurrent readers and writers to interact with
the same queue. A Python implementation of the same algorithm is available at
[https://github.com/cern-mig/python-dirq](https://github.com/cern-mig/python-dirq), a Java implementation at
[https://github.com/cern-mig/java-dirq](https://github.com/cern-mig/java-dirq) and a C implementation at
[https://github.com/cern-mig/c-dirq](https://github.com/cern-mig/c-dirq) so readers and writers can be written
in different programming languages.

There is no knowledge of priority within a queue. If multiple priorities are
needed, multiple queues should be used.

# NAME

Directory::Queue - object oriented interface to a directory based queue

# TERMINOLOGY

An element is something that contains one or more pieces of data. With
[Directory::Queue::Simple](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ASimple) queues, an element can only contain one binary
string. With [Directory::Queue::Normal](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANormal) queues, more complex data schemas can
be used.

A queue is a "best effort" FIFO (First In - First Out) collection of elements.

It is very hard to guarantee pure FIFO behavior with multiple writers using
the same queue. Consider for instance:

- Writer1: calls the add() method
- Writer2: calls the add() method
- Writer2: the add() method returns
- Writer1: the add() method returns

Who should be first in the queue, Writer1 or Writer2?

For simplicity, this implementation provides only "best effort" FIFO,
i.e. there is a very high probability that elements are processed in FIFO
order but this is not guaranteed. This is achieved by using a high-resolution
timer and having elements sorted by the time their final directory gets
created.

# QUEUE TYPES

Different queue types are supported. More detailed information can be found in
the modules implementing these types:

- [Directory::Queue::Normal](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANormal)
- [Directory::Queue::Simple](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ASimple)
- [Directory::Queue::Null](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANull)

Compared to [Directory::Queue::Normal](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANormal), [Directory::Queue::Simple](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ASimple):

- is simpler
- is faster
- uses less space on disk
- can be given existing files to store
- does not support schemas
- can only store and retrieve binary strings
- is not compatible (at filesystem level) with Directory::Queue::Normal

[Directory::Queue::Null](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANull) is special: it is a kind of black hole with the same
API as the other directory queues.

# LOCKING

Adding an element is not a problem because the add() method is atomic.

In order to support multiple reader processes interacting with the same queue,
advisory locking is used. Processes should first lock an element before
working with it. In fact, the get() and remove() methods report a fatal error
if they are called on unlocked elements.

If the process that created the lock dies without unlocking the element, we
end up with a staled lock. The purge() method can be used to remove these
staled locks.

An element can basically be in only one of two states: locked or unlocked.

A newly created element is unlocked as a writer usually does not need to do
anything more with it.

Iterators return all the elements, regardless of their states.

There is no method to get an element state as this information is usually
useless since it may change at any time. Instead, programs should directly try
to lock elements to make sure they are indeed locked.

# CONSTRUCTOR

The new() method of this module can be used to create a Directory::Queue
object that will later be used to interact with the queue. It can have a
`type` attribute specifying the queue type to use. If not specified, the type
defaults to `Simple`.

This method is however only a wrapper around the constructor of the underlying
module implementing the functionality. So:

```perl
$dirq = Directory::Queue->new(type => Foo, ... options ...);
```

is identical to:

```
$dirq = Directory::Queue::Foo->new(... options ...);
```

# INHERITANCE

Regardless of how the directory queue object is created, it inherits from the
`Directory::Queue` class. You can therefore test if an object is a directory
queue (of any kind) by using:

```
if ($object->isa("Directory::Queue")) ...
```

# BASE METHODS

Here are the methods available in the base class and inherited by all
directory queue implementations:

- new(PATH)

    return a new object (class method)

- copy()

    return a copy of the object

- path()

    return the queue toplevel path

- id()

    return a unique identifier for the queue

- first()

    return the first element in the queue, resetting the iterator;
    return an empty string if the queue is empty

- next()

    return the next element in the queue, incrementing the iterator;
    return an empty string if there is no next element

# SECURITY

There are no specific security mechanisms in this module.

The elements are stored as plain files and directories. The filesystem
security features (owner, group, permissions, ACLs...) should be used to
adequately protect the data.

By default, the process' umask is respected. See the class constructor
documentation if you want an other behavior.

If multiple readers and writers with different uids are expected, the easiest
solution is to have all the files and directories inside the toplevel
directory world-writable (i.e. umask=0). Then, the permissions of the toplevel
directory itself (e.g. group-writable) are enough to control who can access
the queue.

# SEE ALSO

[Directory::Queue::Normal](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANormal),
[Directory::Queue::Null](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ANull),
[Directory::Queue::Set](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ASet),
[Directory::Queue::Simple](https://metacpan.org/pod/Directory%3A%3AQueue%3A%3ASimple).

# AUTHOR

Lionel Cons [http://cern.ch/lionel.cons](http://cern.ch/lionel.cons)

Copyright (C) CERN 2010-2024

# AUTHOR

Lionel Cons <lionel.cons@cern.ch>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by CERN.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
