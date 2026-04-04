-- symbols.lua
DarkRuneOrder = DarkRuneOrder or {}

-- Each symbol: id used in messages, label rendered as text, color {r,g,b}
DarkRuneOrder.Symbols = {
    { id = "X",        label = "X",  color = {1,    0.2,  0.2 }, texture = "Interface\\AddOns\\DarkRuneOrder\\texture\\symbol_x.tga"        },
    { id = "Circle",   label = "O",  color = {0.2,  0.8,  1   }, texture = "Interface\\AddOns\\DarkRuneOrder\\texture\\symbol_circle.tga"   },
    { id = "Triangle", label = "^",  color = {0.2,  1,    0.2 }, texture = "Interface\\AddOns\\DarkRuneOrder\\texture\\symbol_triangle.tga" },
    { id = "T",        label = "T",  color = {1,    0.8,  0.2 }, texture = "Interface\\AddOns\\DarkRuneOrder\\texture\\symbol_t.tga"        },
    { id = "Diamond",  label = "<>", color = {0.8,  0.2,  1   }, texture = "Interface\\AddOns\\DarkRuneOrder\\texture\\symbol_diamond.tga"  },
}

-- Fast lookup: DarkRuneOrder.SymbolByID["X"] → symbol table
DarkRuneOrder.SymbolByID = {}
for _, sym in ipairs(DarkRuneOrder.Symbols) do
    DarkRuneOrder.SymbolByID[sym.id] = sym
end
