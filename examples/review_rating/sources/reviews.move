module review_rating::reviews;

use std::string::String;
use sui::clock::Clock;

const EInvalidContentLen: u64 = 1;

const MIN_REVIEW_CONTENT_LEN: u64 = 5;
const MAX_REVIEW_CONTENT_LEN: u64 = 1000;

public struct Review has key, store {
    id: UID,
    owner: address,
    service_id: ID,
    content: String,
    len: u64,
    votes: u64,
    time_issued: u64,
    has_poe: bool,
    total_score: u64,
    overall_rate: u8,
}

public(package) fun new_review(
    owner: address,
    service_id: ID,
    content: String,
    has_poe: bool,
    overall_rate: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Review {
    let len = content.length();
    assert!(len > MIN_REVIEW_CONTENT_LEN && len <= MAX_REVIEW_CONTENT_LEN, EInvalidContentLen);

    let mut review = Review {
        id: object::new(ctx),
        owner,
        service_id,
        content,
        len,
        votes: 0,
        time_issued: clock.timestamp_ms(),
        has_poe,
        total_score: 0,
        overall_rate,
    };
    review.total_score = review.calculate_total_score();
    review
}

public(package) fun delete_review(rev: Review) {
    let Review {
        id,
        owner: _,
        service_id: _,
        content: _,
        len: _,
        votes: _,
        time_issued: _,
        has_poe: _,
        total_score: _,
        overall_rate: _,
    } = rev;
    object::delete(id);
}

fun update_total_score(rev: &mut Review) {
    rev.total_score = rev.calculate_total_score();
}

fun calculate_total_score(rev: &Review): u64 {
    let mut intrinsic_score = rev.len;
    intrinsic_score = intrinsic_score.min(150);

    let extrinsic_score = 10 * rev.votes;
    let vm = if (rev.has_poe) { 2 } else { 1 };
    (intrinsic_score +  extrinsic_score) * vm
}

public fun upvote(rev: &mut Review) {
    rev.votes = rev.votes + 1;
    rev.update_total_score();
}

public fun get_id(rev: &Review): ID {
    rev.id.to_inner()
}

public fun get_total_score(rev: &Review): u64 {
    rev.total_score
}

public fun get_time_issued(rev: &Review): u64 {
    rev.time_issued
}
