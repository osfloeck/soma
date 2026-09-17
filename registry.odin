/*
    registry.odin
    Manages item registration and variable scope
*/

package soma

import "core:fmt"

registry: Registry

@(rodata)item_dummy: Item

Registry :: struct {
    items: map[Item_Key]Item 
}

Variable_Scope :: struct {
    variables: map[string]^Item,
    prev: ^Variable_Scope
}

Item :: struct {
    name: string,
    page: Page,
    items: []Page,
    value: Value,
    type: Item_Type,
}

Item_Key :: struct {
    file_path: string,  // namespace -> blog/post.md
    name: string        // item      -> content
}

Item_Type :: enum {
    Undefined,
    Page,
    Value,
    Array,
}

/*
    Registers a new Item into the global registry
*/
_register_item :: proc(page: Page, path: string, name: string, type: Item_Type) {
    item := Item { name = name }
    switch type {
        case .Undefined:
            fmt.printfln("soma (err): Cannot register {%s, %s} (undefined)", path, name)
        case .Page:
            item.page = page
        case .Value:
        case .Array:
    }
    registry.items[{page.file_path, name}] = item
}

_ephemeral_scope :: proc(scope: ^Variable_Scope, name: string, item: ^Item) {
    scope.variables[name] = item
}

/*
    Walks the scope chain looking for name, returning item_dummy
    (.Undefined) if not found in any scope
*/
_var_scope_lookup :: proc(scope: ^Variable_Scope, name: string) -> (^Item, bool) {
    if scope == nil {
        return &item_dummy, false
    }
    item, ok := scope.variables[name]
    if !ok {
        item, ok = _var_scope_lookup(scope.prev, name)
    }
    return item, ok
}
