module demo::zero {
    use std::debug;

    // 结构体
    public struct MyStruct has copy, drop { i: u64 }

    // 常量
    const ONE: u64 = 1;

    // 函数
    public fun print(x: u64) {
        let sum = x + ONE;
        let _myStruct = MyStruct { i: sum };
        debug::print(&sum)
    }
}

module demo::one {
    public struct Charactor has drop {}

    public fun new(): Charactor { Charactor {} }
}

module demo::caller_module {
    use demo::one::{new, Charactor};

    public fun create_charactor1(): Charactor {
        new()
    }
}

#[allow(duplicate_alias, dead_code, unused_use, unused_const, unused_assignment)]
module demo::two {
    use std::debug;

    // a constant
    const ONE: u64 = 1;

    const RULE: bool = true && false;
    const CAP: u64 = 10 * 100 + 1;
    const HALF_MAX: u128 = 340282366920938463463374607431768211455 / 2;

    // 如果表达式会导致运行时异常,编译器就无法生成常量值,从而报错。
    // const DIV_BY_ZERO: u64 = 1 / 0; // 错误:除零
    // const NEGATIVE_U64: u64 = 0 - 1; // 错误:u64下溢

    // function
    public fun print(_x: u64) {
        // Outer scope
        let x: bool = true;
        let mut y: u8 = 42;
        y = 43;

        {
            // Inner scope
            let _x: u8 = 42; // This is valid because it's in a different scope
            let mut z: u8 = 44;
            z = 45;
        };

        // Back to the outer scope
        // `x` in the outer scope is still a boolean
        let _a: bool = x; // This is valid
    }
}

#[allow(duplicate_alias, dead_code, unused_use, unused_const, unused_assignment)]
module demo::three {
    use std::debug;
    use std::string::String;
    use sui::address;

    #[test]
    public fun address_fun2() {
        // 将地址转换为 u256 类型
        let addr_as_u256: u256 = address::to_u256(@0x1);
        // print: 1
        debug::print(&addr_as_u256);

        // 将 u256 类型转换为地址
        let addr = address::from_u256(addr_as_u256);
        // print: @0x1
        debug::print(&addr);

        // 将地址转换为 vector<u8> 类型
        let addr_as_u8: vector<u8> = address::to_bytes(@0x1);
        // print: 0x0000000000000000000000000000000000000000000000000000000000000001
        debug::print(&addr_as_u8);

        // 将 vector<u8> 类型转换为地址
        let addr = address::from_bytes(addr_as_u8);
        // print: @0x1
        debug::print(&addr);

        // 将地址转换为字符串
        let addr_as_string: String = address::to_string(@0x1);
        // print: "0000000000000000000000000000000000000000000000000000000000000001"
        debug::print(&addr_as_string);
    }
}

#[allow(duplicate_alias, dead_code, unused_use, unused_const, unused_variable)]
module demo::four {
    use std::debug;
    use std::string::{Self, String};

    public struct HackQuestCourse {
        id: u16,
        course: String,
        description: String,
    }

    #[test]
    public fun struct_fun() {
        // create instance
        let mut course1 = HackQuestCourse {
            id: 1_u16,
            course: string::utf8(b"MOVE Course"),
            description: string::utf8(b"it introduces the basic concepts of move"),
        };

        // read
        let course_id: u16 = course1.id;
        debug::print(&course_id);

        // modify
        let course_name: &mut String = &mut course1.course;
        *course_name = string::utf8(b"MOVE Basics");
        debug::print(course_name);

        // delete
        let HackQuestCourse { id, course, description } = course1;
    }
}

module demo::five {
    public struct MyStruct has copy, drop { value: u64 }

    public fun vector_fun() {
        // 创建空 Vector
        let empty = vector::empty<MyStruct>();
        assert!(vector::is_empty(&empty), 0);

        // 创建包含 2 个元素的 Vector
        let mut v = vector[MyStruct { value: 1 }, MyStruct { value: 2 }];
        assert!(vector::length(&v) == 2, 1);

        // 访问元素
        assert!(*vector::borrow(&v, 0) == MyStruct { value: 1 }, 2);

        // 添加元素
        vector::push_back(&mut v, MyStruct { value: 3 });
        assert!(vector::length(&v) == 3, 3);

        // 移除元素
        let last = vector::pop_back(&mut v);
        assert!(last == MyStruct { value: 3 }, 4);

        // 交换元素位置
        vector::swap(&mut v, 0, 1);

        // 包含判断
        assert!(vector::contains(&v, &MyStruct { value: 2 }), 5);

        // 索引查找
        let (ok, idx) = vector::index_of(&v, &MyStruct { value: 1 });
        assert!(ok && idx == 1, 6);

        // 删除指定索引元素
        vector::remove(&mut v, 0);
        assert!(vector::length(&v) == 1, 7);
    }
}

#[allow(duplicate_alias, dead_code, unused_use, unused_const, unused_function)]
module demo::six {
    use std::debug;
    use std::string::{Self, String};

    // 定义 Student 结构体
    public struct Student has drop {
        name: Option<String>,
        age: u64,
    }

    // 创建 Student 实例
    fun create_student(name: Option<String>, age: u64): Student {
        Student { name, age }
    }

    #[test]
    fun option_fun() {
        let student = Student { name: option::none(), age: 18 };
        //let student = Student {name : option::some(string::utf8(b"Alice")), age: 18};

        if (option::is_some(&student.name)) {
            debug::print(&student.name);
        } else {
            debug::print(&string::utf8(b"It is empty."));
        }
    }
}
