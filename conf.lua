function love.conf(t)
  t.version = "11.5"
  t.identity = "adeliefc"

  t.window.title = "Adelie Fight Club"
  t.window.icon = "resources/graphics/icon.png"

  --disable unneeded love2d functions
  t.accelerometerjoystick = false
  t.modules.physics = false
  t.modules.touch = false

  t.console = false
end
