module review_rating::service;

use review_rating::moderator::Moderator;
use review_rating::reviews::{Self, Review};
use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::dynamic_field as df;
use sui::object_table::{Self, ObjectTable};
use sui::sui::SUI;

const EInvalidPermission: u64 = 1;
const ENotEnoughBalance: u64 = 2;
const ENotExists: u64 = 3;

const MAX_REVIEWERS_TO_REWARD: u64 = 10;

public struct AdminCap has key, store {
    id: UID,
    service_id: ID,
}

public struct Service has key, store {
    id: UID,
    reward_pool: Balance<SUI>,
    reward: u64,
    top_reviews: vector<ID>,
    reviews: ObjectTable<ID, Review>,
    overall_rate: u64,
    name: String,
}

public struct ProofOfExperience has key {
    id: UID,
    service_id: ID,
}

public struct ReviewRecord has drop, store {
    owner: address,
    overall_rate: u8,
    time_issued: u64,
}

#[allow(lint(self_transfer))]
public fun create_service(name: String, ctx: &mut TxContext): ID {
    let id = object::new(ctx);
    let service_id = id.to_inner();
    let service = Service {
        id,
        reward: 1_000_000,
        reward_pool: balance::zero(),
        reviews: object_table::new(ctx),
        top_reviews: vector[],
        overall_rate: 0,
        name,
    };
    let admin_cap = AdminCap { id: object::new(ctx), service_id };
    transfer::share_object(service);
    transfer::public_transfer(admin_cap, ctx.sender());
    service_id
}

public fun write_new_review(
    service: &mut Service,
    owner: address,
    content: String,
    overall_rate: u8,
    clock: &Clock,
    poe: ProofOfExperience,
    ctx: &mut TxContext,
) {
    assert!(poe.service_id == service.id.to_inner(), EInvalidPermission);
    let ProofOfExperience { id, service_id: _ } = poe;
    id.delete();

    let review = reviews::new_review(
        owner,
        service.id.to_inner(),
        content,
        true,
        overall_rate,
        clock,
        ctx,
    );
    service.add_review(review, owner, overall_rate);
}

fun add_review(service: &mut Service, review: Review, owner: address, overall_rate: u8) {
    let id = review.get_id();
    let total_score = review.get_total_score();
    let time_issued = review.get_time_issued();

    service.reviews.add(id, review);
    service.update_top_reviews(id, total_score);

    df::add(
        &mut service.id,
        id,
        ReviewRecord {
            owner,
            overall_rate,
            time_issued,
        },
    );

    let overall_rate = (overall_rate as u64);
    service.overall_rate = service.overall_rate+ overall_rate;
}

fun should_update_top_reviews(service: &Service, total_score: u64): bool {
    let len = service.top_reviews.length();
    len < MAX_REVIEWERS_TO_REWARD || total_score > service.get_total_score(service.top_reviews[len - 1])
}

fun prune_top_reviews(service: &mut Service) {
    while (service.top_reviews.length() > MAX_REVIEWERS_TO_REWARD) {
        service.top_reviews.pop_back();
    };
}

fun update_top_reviews(service: &mut Service, review_id: ID, total_score: u64) {
    if (service.should_update_top_reviews(total_score)) {
        let idx = service.find_idx(total_score);
        service.top_reviews.insert(review_id, idx);
        service.prune_top_reviews();
    }
}

fun find_idx(service: &Service, total_score: u64): u64 {
    let mut i = service.top_reviews.length();
    while (0<i) {
        let review_id = service.top_reviews[i-1];
        if (service.get_total_score(review_id) > total_score) {
            break
        };
        i = i -1;
    };
    i
}

fun get_total_score(service: &Service, review_id: ID): u64 {
    service.reviews[review_id].get_total_score()
}

public fun distribute_reward(cap: &AdminCap, service: &mut Service, ctx: &mut TxContext) {
    assert!(cap.service_id == service.id.to_inner(), EInvalidPermission);
    let mut len = service.top_reviews.length();
    if (len > MAX_REVIEWERS_TO_REWARD) {
        len = MAX_REVIEWERS_TO_REWARD;
    };
    assert!(service.reward_pool.value() >= (service.reward * len), ENotEnoughBalance);

    let mut i = 0;
    while (i < len) {
        let sub_balance = service.reward_pool.split(service.reward);
        let reward = coin::from_balance(sub_balance, ctx);
        let review_id = &service.top_reviews[i];
        let record = df::borrow<ID, ReviewRecord>(&service.id, *review_id);
        transfer::public_transfer(reward, record.owner);
        i = i+1;
    }
}

public fun top_up_reward(service: &mut Service, coin: Coin<SUI>) {
    service.reward_pool.join(coin.into_balance());
}

public fun generate_proof_of_experience(
    cap: &AdminCap,
    service: &Service,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(cap.service_id == service.id.to_inner(), EInvalidPermission);
    let poe = ProofOfExperience { id: object::new(ctx), service_id: cap.service_id };
    transfer::transfer(poe, recipient);
}

public fun remove_review(_: &Moderator, service: &mut Service, review_id: ID) {
    assert!(service.reviews.contains(review_id), ENotExists);
    let record: ReviewRecord = df::remove(&mut service.id, review_id);
    service.overall_rate = service.overall_rate - (record.overall_rate as u64);
    let (contains, i) = service.top_reviews.index_of(&review_id);
    if (contains) {
        service.top_reviews.remove(i);
    };
    service.reviews.remove(review_id).delete_review();
}

fun recorder(service: &mut Service, review_id: ID, total_score: u64) {
    let (contains, i) = service.top_reviews.index_of(&review_id);
    if (!contains) {
        service.update_top_reviews(review_id, total_score);
    } else {
        service.top_reviews.remove(i);
        let idx = service.find_idx(total_score);
        service.top_reviews.insert(review_id, idx);
    }
}

public fun upvoew(service: &mut Service, review_id: ID) {
    let review = &mut service.reviews[review_id];
    review.upvote();
    service.recorder(review_id, review.get_total_score());
}
