module solve::solve {
    use movectf::move_lock::{Self, ResourceObject};
    use sui::tx_context::{TxContext};

    public entry fun solve(resource_object: &mut ResourceObject, ctx: &mut TxContext) {
        let data1 : vector<u64> = vector[28, 14, 13, 32, 17,  0, 19, 46, 11,
                                          0, 19,  8, 14, 13, 18, 24, 14, 20,
                                         12,  0, 39,  0,  6, 30,  3, 19, 40,
                                          1, 17,  4, 26, 10, 19,  7,  4,  7,
                                         34, 11, 11,  2, 34, 15, 33,  4, 17,
                                          7,  0, 28, 10, 19,  7,  4, 33,  0, 
                                          2, 62, 24, 15, 37,  0, 13, 30, 19];
        let data2 : vector<u64> = vector[25, 11, 32, 10, 13, 25, 38, 19, 2];
        move_lock::movectf_unlock(data1, data2, resource_object, ctx);
        move_lock::get_flag(resource_object, ctx);
    }
}
