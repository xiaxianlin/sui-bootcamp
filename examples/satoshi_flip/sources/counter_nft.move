module satoshi_flip::counter_nft;

use sui::bcs;

/// 生成 VRF 输入的计数器
/// VRF 可验证随机函数
public struct Counter has key {
    id: UID,
    count: u64,
}

/// 销毁计数器
entry fun burn(self: Counter) {
    let Counter { id, count: _ } = self;
    id.delete();
}

/// 生成计数器
public fun mint(ctx: &mut TxContext): Counter {
    Counter { id: object::new(ctx), count: 0 }
}

/// 计数器转一个给玩家
public fun transfer_to_sender(counter: Counter, ctx: &mut TxContext) {
    transfer::transfer(counter, ctx.sender());
}

/// 获取 VRF 的输入并计数器累加
public fun get_vrf_input_and_increment(self: &mut Counter): vector<u8> {
    // 生成输入
    let mut vrf_input = object::id_bytes(self);
    // 根据计数进行加密
    let count_to_bytes = bcs::to_bytes(&count(self));
    vrf_input.append(count_to_bytes);
    self.count = self.count + 1;
    vrf_input
}

public fun count(self: &Counter): u64 {
    self.count
}

#[test_only]
public fun burn_for_testing(self: Counter) {
    self.burn();
}
