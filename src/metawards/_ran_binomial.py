

__all__ = ["ran_binomial", "seed_ran_binomial"]


# The plan with this file is to move to an inline cdef that just
# calls the gsl_ran_binomial function directly. Moving away from
# pygsl (and indeed probably gsl) as this is too heavyweight an
# import just to use a random binomial generator. The signature
# of this function in the code will remain though...


def seed_ran_binomial(seed: int = None):
    """Seed and return the random binomial generator. This returns
       the object that you should pass to ran_binomial to generate
       random numbers drawn from a binomial distribution
    """
    from pygsl import rng as gsl_rng

    rng = gsl_rng.rng()

    if seed is None:
        import random
        seed = random.randint(10000, 99999999)

    print(f"Using random number seed: {seed}")
    rng.set(seed)

    # test seeding of the random number generator by drawing and printing
    # 5 random numbers - this is temporary, and only used to
    # facilitate comparison to the original C code
    for i in range(1,6):
        r = ran_binomial(rng, 0.5, 100)
        print(f"random number {i} equals {r}")

    return rng


def ran_binomial(rng, p: float, n: int):
    """Return a random number drawn from the binomial distribution
       [p,n] (see gsl_ran_binomial for documentation)
    """
    return rng.binomial(p, n)
