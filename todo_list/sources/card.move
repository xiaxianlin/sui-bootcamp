module todo_list::card;

public struct IngoreMe has drop {
    a: u8,
    b: u8,
}

public struct NoDrop {}

#[test]
fun test_ignore() {
    let no_drop = NoDrop {};
    let _ = IngoreMe { a: 1, b: 2 };

    let NoDrop {} = no_drop;
}

public struct Cat has drop {}
public struct Dog has drop {}

public use fun cat_run as Cat.run;

public fun cat_run(_cat: &Cat) {}

public use fun dog_run as Dog.run;

public fun dog_run(_dog: &Dog) {}

#[test]
fun test_run() {
    let cat = Cat {};
    cat.run();

    let dog = Dog {};
    dog.run();
}
