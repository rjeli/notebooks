from hashlib import blake2s
from binascii import hexlify

def log2_strict(n):
    logn = log(n, 2).n()
    assert logn.is_integer()
    return int(logn)

def two_adic_generator(field, bits):
    two_adicity = dict(factor(field.order() - 1))[2]
    assert bits <= two_adicity, f'need two-adicity of {bits} but have {two_adicity}'
    if field.degree() == 1:
        g = field.multiplicative_generator()
        return g^((field.order()-1)/(2^bits))
    else:
        # make sure that for an extension, the base subgroup is a subset of our subgroup
        base_two_adicity = dict(factor(field.base().order() - 1))[2]
        if bits <= base_two_adicity:
            return field(two_adic_generator(field.base(), bits))
        else:
            g = field(two_adic_generator(field.base(), base_two_adicity))
            for _ in range(bits - base_two_adicity):
                assert g.is_square(), 'not a square?'
                g = g.sqrt()
            return g

def two_adic_subgroup(field, bits, shift=1):
    g = two_adic_generator(field, bits)
    return [shift*g^i for i in range(2^bits)]

def powers(base, n=None):
    i = 0
    cur = base.parent()(1)
    while True:
        if n is not None and i == n:
            return
        yield cur
        cur *= base
        i += 1

def field_size(f):
    return int((log(f.order(), 2)/8).n().ceil())

def to_bytes(x):
    if isinstance(x, bytes):
        return x
    elif isinstance(x, str):
        return x.encode('utf8')
    elif isinstance(x, int):
        # assume < u64
        return x.to_bytes(8, 'little')
    try:
        p = x.parent()
        if p is ZZ:
            return int(x).to_bytes(8, 'little')
        elif p.is_finite():
            if p.degree() == 1:
                return int(x).to_bytes(field_size(x.parent()), 'little')
            else:
                return b''.join(to_bytes(x[i]) for i in range(p.degree()))
    except Exception as e:
        print(e)
        pass
    assert False, f"don't know how to convert {type(x)} to bytes"

def compress(*xs):
    return blake2s(b''.join(to_bytes(x) for x in xs)).digest()

class MerkleTree:
    def __init__(self, leaves):
        self.leaves = list(leaves)
        self.levels = [[compress(l)[:4] for l in leaves]]
        while len(self.levels[-1]) > 1:
            new_level = [
                # only 4 bytes so its not annoying in notebook
                compress(l, r)[:4]
                for l, r in zip(self.levels[-1][::2], self.levels[-1][1::2])
            ]
            self.levels.append(new_level)
        assert len(self.levels) == log2_strict(len(self.levels[0])) + 1
        
    def root(self):
        return hexlify(self.levels[-1][0])
        
    def open(self, idx):
        leaf = self.leaves[idx]
        sibs = []
        for l in self.levels[:-1]:
            sibs.append(l[idx ^^ 1])
            idx >>= 1
        assert idx == 0
        return leaf, sibs
        
    @staticmethod
    def verify(root, idx, leaf, sibs):
        h = compress(leaf)[:4]
        for s in sibs:
            l, r = (s, h) if idx & 1 else (h, s)
            h = compress(l, r)[:4]
            idx >>= 1
        assert idx == 0 and hexlify(h) == root

def test_mt():
    xs = matrix.random(GF(17), 1, 16).row(0)
    mt = MerkleTree(xs)
    leaf, sibs = mt.open(15)
    assert leaf == xs[15]
    MerkleTree.verify(mt.root(), 15, leaf, sibs)
test_mt()

def deep_iter(xs):
    if hasattr(xs, 'coefficients'):
        yield from xs.coefficients()
    else:
        try:
            for x in xs:
                yield from deep_iter(x)
        except TypeError:
            yield xs

# not actually a sponge
class Transcript:
    def __init__(self):
        self.state = b'x' * 32

    def observe(self, xs):
        for x in deep_iter(xs):
            self.state = compress(self.state, x)

    def challenge(self, field):
        self.observe(0)
        with seed(int.from_bytes(self.state)):
            return field.random_element()

def test_transcript():
    t0 = Transcript(); t0.observe(1)
    t1 = Transcript(); t1.observe(1)
    assert t0.challenge(GF(5)) == t1.challenge(GF(5))
    t0.observe(2)
    assert t0.challenge(GF(5)) != t1.challenge(GF(5))

test_transcript()
