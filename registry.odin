package soma

// Registry
registry: Registry

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

Variable_Scope :: struct {
    variables: map[string]^Item,
    prev: ^Variable_Scope
}

Item_Key :: struct {
    file_path: string,
    name: string
}

Item_Type :: enum {
    Undefined,
    Page,
    Array,
    Value,
}

Item :: struct {
    file_path: string,
    name: string,
    page: Page,
    items: []Page,
    value: Value,
    type: Item_Type,
}

@(rodata)item_dummy: Item

Registry :: struct {
    items: map[Item_Key]Item 
}