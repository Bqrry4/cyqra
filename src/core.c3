module cyqra::core::arena;

BackedArenaAllocator* alloc;

fn void init() {
    alloc = allocators::new_backed_allocator(4 * 4096, mem)!!;
}

