=====
Usage
=====

metawards program
=================

MetaWards comes with a command-line program called ``metawards``.
This is installed by default into the same directory as the
``python`` executable used to build the package. To run ``metawards``
type;

.. code-block:: bash

    metawards --version

This prints out the version of ``metawards``, which should look something
like this;

.. program-output:: metawards --version

This version information gives you the provenance of this executable which
should help in reproducing output. It is written to the top of all
metawards outputs.

If you see output like this, with ``WARNING`` lines about the version
being ``dirty``...

::

    *****************************************
    metawards version 0.3.0+58.g6e1f4c4.dirty
    *****************************************

             -- Source information --
 repository: https://github.com/metawards/MetaWards
                  branch: devel
 revision: 6e1f4c45092ec345ee3673709d780ebe71ca0309
     last modified: 2020-04-09T17:57:18+0100

 WARNING: This version has not been committed to git,
 WARNING: so you may not be able to recover the original
 WARNING: source code that was used to generate this run!

           -- Additional information --
 Visit https://metawards.github.io for more informaion
   about metawards, its authors and its license

then this means that your ``metawards`` executable has been built using
source code that has not been committed to git, and is therefore not
version controlled. Do not use ``dirty`` software for production jobs
as it will not be possible to recover the software used to produce
outputs at a later date, and thus it may not be possile to reproduce
results.

Getting help
============

The ``metawards`` program has up-to-date and very comprehensive in-built
help for all of its command line options. You can print this help by
typing;

.. code-block:: bash

    metawards --help

The full help is :doc:`available here <metawards_help>`.

.. toctree::
   :hidden:

   metawards_help

Understanding the options
=========================

``metawards`` is a powerful program so it comes with a lot of options.
The most used and thus most important options are given first. These
are;

* ``--input`` : Specify the input file adjustable parameters that will be
  explored for the model run. You must supply an input file to be
  able to run a model. This file is described below.

* ``--line`` : Specify the line number (or line numbers) of adjustable
  parameter sets from the input file. Line numbers are counted from 0, and
  multiple line numbers can be given, e.g. ``--line 3, 5, 7-10`` will
  read from lines 3, 5, 7, 8, 9, and 10 (remembering that the first line
  of the file is line 0). If multiple lines are read, then multiple model
  runs will be performed.

* ``--repeats`` : specify the number of times model runs for each
  adjustable parameter set should be repeated. MetaWards model runs
  are stochastic, based on random numbers. The results for multiple
  runs must thus be processed to derive meaning.

* ``--additional`` : specify the file (or files) containing additional
  seeds. These files are described in `Model data <model_data.html>`__.
  You can specify as many or few files as you wish. If the file exists
  in your path then that will be used. Otherwise the file will be
  searched for from the ``MetaWardsData/extra_seeds`` directory.

* ``--output`` : specify the location to place all output files. By default
  this will be in a new directory called ``output``. A description of the
  output files is below.

* ``--seed`` : specify the random number seed to use for a run. By default
  a truly random seed will be used. This will be printed into the output,
  so that you can use it together with this option to reproduce a run.
  The same version of ``metawards`` will reproduce the same output when
  given the same input, same random number seed, and run over the
  same number of threads.

* ``--start-date`` : specify the date of *day zero* of the model outbreak.
  If this isn't specified then this defaults to the current date. This
  recognises any date that is understood by
  `dateparser <https://dateparser.readthedocs.io/en/latest/#usage>`__,
  which includes dates like *today*, *tomorrow*, *Monday*, *Jan 2020* etc.
  The start date is used to trigger events based on day of week or
  date within a model outbreak (e.g. is the day a weekend)

* ``--start-day`` : specify the day of the outbreak, e.g. the default
  is ``0`` for *day zero*. This is useful if you want to start the
  model run from a later day than the start date. Note that the
  start date passed via ``--start-date`` is the date of *day zero*,
  so the first day modelled will be ``--start-day`` days
  after ``--start-date``.

* ``--nthreads`` : specify the number of threads over which to perform a
  model run. The sequence of random numbers drawn in parallel is
  deterministic for a given number of threads, but will be different
  for different numbers of threads. This is why you can only reproduce
  a model run using a combination of the same random number seed and
  same number of threads. The number of threads used for a model run
  is written into the output.

* ``--nprocs`` : specify the number of processes over which you want
  to parallelise the model runs. This is useful if you have multiple
  processors on your computer and you are running multiple model runs.
  Note that this option is set automatically for you if you are
  `running on a cluster <cluster_usage.html>`__.

Using these options, a typical ``metawards`` run can be performed
using;

.. code-block:: bash

    metawards --input params.csv --line 0

This python port of ``metawards`` was written to reproduce the output
of the original C code. This original code is bundled with this
port and is in the ``original`` directory. You can reproduce the output
of this code using the command;

.. code-block:: bash

    metawards --input tests/data/ncovparams.csv --line 0 --seed 15324 --nthreads 1 --additional ExtraSeedsBrighton.dat

The output from this command can be compared to that from the original
C program in ``original/expected_test_output.txt``. Comparing against this
original output is also the purpose of the unit test
``tests/test_integration.py``.

Understanding the input
=======================

The input file for ``metawards`` is a simple set of lines containing
five comma-separated or space-separated values per line, e.g.

::

  0.95,0.95,0.19,0.91,0.91
  0.90,0.93,0.18,0.92,0.90

or

::

  0.90 0.93 0.18 0.92 0.90

These five values per line adjust the ``beta[2]``, ``beta[3]``,
``progress[1]``, ``progress[2]`` and ``progress[3]`` parameters of
the ``disease`` model as described in `Model Data <model_data.html>`__.

You can optionally choose which parameters will be varied by adding
a title line, e.g.

::

  beta[2]   progress[2]   progress[3]
    0.90        0.92         0.90
    0.85        0.91         0.92

specifies that you want to adjust the ``beta[2]``, ``progress[2]`` and
``progress[3]`` parameters to the specified values.

The full list of parameters you can adjust are listed below;

.. program-output:: python get_variableset_help.py

Understanding the output
========================

The output of ``metawards`` is primarily a trajectory of the outbreak
through the model population. This is reported daily from the first
day (day 0) until the outbreak ends. For single runs this is printed
to the screen, e.g.

::

   21 58
  S: 56081959    E: 52    I: 17    R: 49    IW: 9   TOTAL POPULATION 56082025

A model run moves individuals between different states according to
whether they become infected, and then progress through the outbreak.
The codes mean;

* `S` : number who are susceptible to infection (and not infected)
* `E` : number who are infected but not yet infectious (latent)
* `I` : number who are infected, infectious and symptomatic
* `IW` : number of wards that have at least one infected individual
* `R` : number who are recovered from the infection and thus immune

As well as being printed to the screen, this data is also written
to the CSV file ``output/results.csv.bz2`` for easy reading and analysis
using R or Python pandas.

If multiple model runs are performed, then each run is given a fingerprint
based on the adjustable parameters and repeat number. The output is written
to ``output/[fingerprint]_[repeat]/output.txt``. In addition, results
for all of the runs are combined into a single ``output/results.csv.bz2``
file for easy combined analysis.

For example, this output could be read into a pandas dataframe using

.. code-block:: python

    import pandas as pd

    df = pd.read_csv("output/results.csv.bz2")

    df # perform analysis

We run a good online workshop on
`how to use pandas for data analysis <https://milliams.com/courses/data_analysis_python/index.html>`__.

metawards-plot
--------------

For quick and simple plots, ``metawards`` comes with the command-line
program ``metawards-plot``. This can be used to create plots of the
data in the ``output/results.csv.bz2`` file using, e.g.

.. code-block:: bash

   metawards-plot --input output/results.csv.bz2

For full help on this program using ``metawards-plot --help``.
The full help is :doc:`available here <metawards_plot_help>`.

.. toctree::
   :hidden:

   metawards_plot_help