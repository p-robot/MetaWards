
from typing import Union as _Union
from typing import List as _List

from cython.parallel import parallel, prange

from libc.math cimport ceil

from .._networks import Networks
from .._infections import Infections
from .._demographics import DemographicID, DemographicIDs

from ..utils._get_array_ptr cimport get_int_array_ptr, get_double_array_ptr

__all__ = ["go_isolate", "go_isolate_serial", "go_isolate_parallel"]


def go_isolate_parallel(go_from: _Union[DemographicID, DemographicIDs],
                        go_to: DemographicID,
                        network: Networks,
                        infections: Infections,
                        nthreads: int,
                        self_isolate_stage: _Union[_List[int], int] = 2,
                        fraction: _Union[_List[float], float] = 1.0,
                        **kwargs) -> None:
    """This go function will move individuals from the "from"
       demographic(s) to the "to" demographic if they show any
       signs of infection (the disease stage is greater or equal
       to 'self_isolate_stage' - by default this is level '2',
       which is one level above "latent").

       Parameters
       ----------
       from: DemographicID or DemographicIDs
         ID (name or index) or IDs of the demographics to scan for
         infected individuals
       to: DemographicID
         ID (name or index) of the isolation demographic to send infected
         individuals to
       network: Networks
         The networks to be modelled. This must contain all of the
         demographics that are needed for this go function
       self_isolate_stage: int or List[int]
         The stage of infection an individual must be at before they
         are moved into this demographic. If a list is passed then
         this can be multiple stages, e.g. [2, 3] will move at
         stages 2 and 3. Multiple stages are needed if only
         a fraction of individuals move.
       fraction: float or List[float]
         The fraction (percentage) of individuals who are moved from
         this stage into isolation. If this is a single value then
         the same fraction applies to all self_isolation_stages. Otherwise,
         the fraction for self_isolate_stage[i] is fraction[i]
    """

    # make sure that all of the needed demographics exist, and
    # convert them into a canonical form (indexes, list[indexes])
    if not isinstance(go_from, list):
        go_from = [go_from]

    subnets = network.subnets
    demographics = network.demographics
    subinfs = infections.subinfs

    go_from = [demographics.get_index(x) for x in go_from]

    go_to = demographics.get_index(go_to)

    to_subnet = subnets[go_to]
    to_subinf = subinfs[go_to]

    if isinstance(self_isolate_stage, list):
        stages = [int(stage) for stage in self_isolate_stage]
    else:
        stages = [int(self_isolate_stage)]

    if isinstance(fraction, list):
        fractions = [float(frac) for frac in fraction]
    else:
        fractions = [float(fraction)] * len(stages)

    for fraction in fractions:
        if fraction < 0 or fraction > 1:
            raise ValueError(
                f"The move fractions {fractions} should all be 0 to 1")

    N_INF_CLASSES = infections.N_INF_CLASSES

    for stage in stages:
        if stage < 1 or stage >= N_INF_CLASSES:
            raise ValueError(
                f"The stage(s) of self-isolation {stages} "
                f"is invalid for a disease with {N_INF_CLASSES} stages")

    if len(stages) != len(fractions):
        raise ValueError(
            f"The number of self isolation stages {stages} must equal "
            f"the number of fractions {fractions}")

    cdef int nnodes_plus_one = 0
    cdef int nlinks_plus_one = 0

    cdef int to_move = 0

    cdef int * work_infections_i
    cdef int * play_infections_i

    cdef int * to_work_infections_i
    cdef int * to_play_infections_i

    cdef int nsubnets = len(subnets)

    cdef int num_threads = nthreads

    cdef int ii = 0
    cdef int i = 0
    cdef int j = 0

    cdef double fraction_i = 1.0

    for ii in go_from:
        subnet = subnets[ii]
        subinf = subinfs[ii]
        nnodes_plus_one = subinf.nnodes + 1
        nlinks_plus_one = subinf.nlinks + 1

        for i, fraction in zip(stages, fractions):
            fraction_i = fraction

            work_infections_i = get_int_array_ptr(subinf.work[i])
            play_infections_i = get_int_array_ptr(subinf.play[i])

            to_work_infections_i = get_int_array_ptr(to_subinf.work[i])
            to_play_infections_i = get_int_array_ptr(to_subinf.play[i])

            with nogil, parallel(num_threads=num_threads):
                if fraction_i == 1.0:
                    for j in prange(1, nlinks_plus_one, schedule="static"):
                        if work_infections_i[j] > 0:

                            to_work_infections_i[j] = \
                                                to_work_infections_i[j] + \
                                                work_infections_i[j]
                            work_infections_i[j] = 0

                    for j in prange(1, nnodes_plus_one, schedule="static"):
                        if play_infections_i[j] > 0:
                            to_play_infections_i[j] = \
                                                to_play_infections_i[j] + \
                                                play_infections_i[j]
                            play_infections_i[j] = 0
                else:
                    for j in prange(1, nlinks_plus_one, schedule="static"):
                        to_move = <int>(ceil(fraction_i *
                                             work_infections_i[j]))
                        if to_move > 0:
                            to_work_infections_i[j] = \
                                                to_work_infections_i[j] + \
                                                to_move
                            work_infections_i[j] = \
                                                work_infections_i[j] - \
                                                to_move

                    for j in prange(1, nnodes_plus_one, schedule="static"):
                        to_move = <int>(ceil(fraction_i *
                                             play_infections_i[j]))
                        if to_move > 0:
                            to_play_infections_i[j] = \
                                                to_play_infections_i[j] + \
                                                to_move
                            play_infections_i[j] = \
                                                play_infections_i[j] - \
                                                to_move


def go_isolate_serial(go_from: _Union[DemographicID, DemographicIDs],
                      go_to: DemographicID,
                      network: Networks,
                      infections: Infections,
                      self_isolate_stage: _Union[_List[int], int] = 2,
                      fraction: _Union[_List[float], float] = 1.0,
                      **kwargs) -> None:
    """This go function will move individuals from the "from"
       demographic(s) to the "to" demographic if they show any
       signs of infection (the disease stage is greater or equal
       to 'self_isolate_stage' - by default this is level '2',
       which is one level above "latent").

       Parameters
       ----------
       from: DemographicID or DemographicIDs
         ID (name or index) or IDs of the demographics to scan for
         infected individuals
       to: DemographicID
         ID (name or index) of the demographic to send infected
         individuals to
       network: Networks
         The networks to be modelled. This must contain all of the
         demographics that are needed for this go function
       self_isolate_stage: int or List[int]
         The stage of infection an individual must be at before they
         are moved into this demographic. If a list is passed then
         this can be multiple stages, e.g. [2, 3] will move at
         stages 2 and 3. Multiple stages are needed if only
         a fraction of individuals move.
       fraction: float or List[float]
         The fraction (percentage) of individuals who are moved from
         this stage into isolation. If this is a single value then
         the same fraction applies to all self_isolation_stages. Otherwise,
         the fraction for self_isolate_stage[i] is fraction[i]
    """

    # make sure that all of the needed demographics exist, and
    # convert them into a canonical form (indexes, list[indexes])
    if not isinstance(go_from, list):
        go_from = [go_from]

    subnets = network.subnets
    demographics = network.demographics
    subinfs = infections.subinfs

    go_from = [demographics.get_index(x) for x in go_from]

    go_to = demographics.get_index(go_to)

    to_subnet = subnets[go_to]
    to_subinf = subinfs[go_to]

    if isinstance(self_isolate_stage, list):
        stages = [int(stage) for stage in self_isolate_stage]
    else:
        stages = [int(self_isolate_stage)]

    if isinstance(fraction, list):
        fractions = [float(frac) for frac in fraction]
    else:
        fractions = [float(fraction)] * len(stages)

    for fraction in fractions:
        if fraction < 0 or fraction > 1:
            raise ValueError(
                f"The move fractions {fractions} should all be 0 to 1")

    N_INF_CLASSES = infections.N_INF_CLASSES

    for stage in stages:
        if stage < 1 or stage >= N_INF_CLASSES:
            raise ValueError(
                f"The stage(s) of self-isolation {stages} "
                f"is invalid for a disease with {N_INF_CLASSES} stages")

    if len(stages) != len(fractions):
        raise ValueError(
            f"The number of self isolation stages {stages} must equal "
            f"the number of fractions {fractions}")

    cdef int nnodes_plus_one = 0
    cdef int nlinks_plus_one = 0

    cdef int to_move = 0

    cdef int * work_infections_i
    cdef int * play_infections_i

    cdef int * to_work_infections_i
    cdef int * to_play_infections_i

    cdef int nsubnets = len(subnets)

    cdef int ii = 0
    cdef int i = 0
    cdef int j = 0

    cdef double fraction_i = 1.0

    for ii in go_from:
        subnet = subnets[ii]
        subinf = subinfs[ii]
        nnodes_plus_one = subinf.nnodes + 1
        nlinks_plus_one = subinf.nlinks + 1

        for i, fraction in zip(stages, fractions):
            fraction_i = fraction

            work_infections_i = get_int_array_ptr(subinf.work[i])
            play_infections_i = get_int_array_ptr(subinf.play[i])

            to_work_infections_i = get_int_array_ptr(to_subinf.work[i])
            to_play_infections_i = get_int_array_ptr(to_subinf.play[i])

            if fraction_i == 1.0:
                for j in range(1, nlinks_plus_one):
                    if work_infections_i[j] > 0:
                        to_work_infections_i[j] = to_work_infections_i[j] + \
                                                  work_infections_i[j]
                        work_infections_i[j] = 0

                for j in range(1, nnodes_plus_one):
                    if play_infections_i[j] > 0:
                        to_play_infections_i[j] = to_play_infections_i[j] + \
                                                  play_infections_i[j]
                        play_infections_i[j] = 0
            else:
                for j in range(1, nlinks_plus_one):
                    to_move = <int>(ceil(fraction_i * work_infections_i[j]))
                    if to_move > 0:
                        to_work_infections_i[j] = to_work_infections_i[j] + \
                                                  to_move
                        work_infections_i[j] = work_infections_i[j] - \
                                               to_move

                for j in range(1, nnodes_plus_one):
                    to_move = <int>(ceil(fraction_i * play_infections_i[j]))
                    if to_move > 0:
                        to_play_infections_i[j] = to_play_infections_i[j] + \
                                                  to_move
                        play_infections_i[j] = play_infections_i[j] - \
                                               to_move


def go_isolate(nthreads: int = 1, **kwargs) -> None:
    """This go function will move individuals from the "from"
       demographic(s) to the "to" demographic if they show any
       signs of infection (the disease stage is greater or equal
       to 'self_isolate_stage' - by default this is level '2',
       which is one level above "latent"). Individuals are held
       in the new demographic for "duration" days, before being
       returned either to their original demographic, or
       released to the "release_to" demographic

       Parameters
       ----------
       from: DemographicID or DemographicIDs
         ID (name or index) or IDs of the demographics to scan for
         infected individuals
       to: DemographicID
         ID (name or index) of the demographic to send infected
         individuals to
       network: Networks
         The networks to be modelled. This must contain all of the
         demographics that are needed for this go function
       self_isolate_stage: int
         The stage of infection an individual must be at before they
         are moved into this demographic
       duration: int
         The number of days an individual should isolate for
       release_to: DemographicID
         ID (name or index) that the individual should move to after
         existing isolation. If this is not set, then the individual
         will return to their original demographic
    """

    if nthreads > 1:
        go_isolate_parallel(nthreads=nthreads, **kwargs)
    else:
        go_isolate_serial(**kwargs)
