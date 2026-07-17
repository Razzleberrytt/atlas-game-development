from pathlib import Path

path = Path("games/living-kingdoms/tests/WeaponController.test.luau")
text = path.read_text()
old = '''local function activeInstance(className: string)
\tfor index = #createdInstances, 1, -1 do
\t\tlocal instance = createdInstances[index]
\t\tif instance.ClassName == className and not instance.destroyed then
\t\t\treturn instance
\t\tend
\tend
\treturn nil
end
'''
new = '''local function activeInstance(className: string, instanceName: string?)
\tfor index = #createdInstances, 1, -1 do
\t\tlocal instance = createdInstances[index]
\t\tif
\t\t\tinstance.ClassName == className
\t\t\tand not instance.destroyed
\t\t\tand (instanceName == nil or instance.Name == instanceName)
\t\tthen
\t\t\treturn instance
\t\tend
\tend
\treturn nil
end
'''
if text.count(old) != 1:
    raise RuntimeError(f"expected one activeInstance helper, found {text.count(old)}")
text = text.replace(old, new, 1)
old_status = 'local statusLabel = activeInstance("TextLabel")'
new_status = 'local statusLabel = activeInstance("TextLabel", "Status")'
if text.count(old_status) != 1:
    raise RuntimeError(f"expected one status lookup, found {text.count(old_status)}")
path.write_text(text.replace(old_status, new_status, 1))
