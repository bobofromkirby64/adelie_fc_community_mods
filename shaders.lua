whiteShader = love.graphics.newShader[[
    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        // Get the color of the pixel from the spritesheet
        vec4 texturecolor = Texel(tex, texture_coords);
        
        // If the pixel is completely transparent, leave it transparent.
        // Otherwise, make it pure white (1.0, 1.0, 1.0) while keeping its original alpha.
        if (texturecolor.a == 0.0) {
            return vec4(0.0);
        }
        return vec4(1.0, 1.0, 1.0, texturecolor.a) * color;
    }
]]

paletteSwapShader = love.graphics.newShader[[
    extern vec4 color_find;
    extern vec4 color_replace;

    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 pixel = Texel(tex, texture_coords);
        
        // If the pixel matches the target color (with a tiny 0.02 margin for float precision)
        if (distance(pixel.rgb, color_find.rgb) < 0.02 && pixel.a > 0.0) {
            return vec4(color_replace.rgb, pixel.a) * color;
        }
        return pixel * color;
    }
]]

outlineShader = love.graphics.newShader[[
    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 pixel = Texel(tex, texture_coords);
        // If the pixel exists at all, force it to be pure black
        if (pixel.a > 0.0) {
            return vec4(0.0, 0.0, 0.0, 1.0);
        }
        return vec4(0.0, 0.0, 0.0, 0.0);
    }
]]

menuBGShader = love.graphics.newShader[[
    extern float time;

    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {
        // gradient
        vec4 black = vec4(0, 0, 0, 1);
        vec4 blue = vec4(29.0/255.0, 43.0/255.0, 83.0/255.0, 1);

        vec4 col = black;
        if (screen_coords.y > 100.0){
            col = blue;
        } else if (screen_coords.y > 90.0){
            col = mod(screen_coords.x, 2.0)<1.0 && mod(screen_coords.y, 2.0)<1.0 ? black : blue;
        } else if (screen_coords.y > 80.0){
            col = mod(screen_coords.y, 2.0) == mod(screen_coords.x, 2.0) ? blue : black;
        } else if (screen_coords.y > 70.0) {
            col = mod(screen_coords.x, 2.0)<1.0 && mod(screen_coords.y, 2.0)<1.0 ? blue : black;
        }

        col.rgb *= 0.5;

        // diagonal lines
        float diagonal = screen_coords.x + screen_coords.y;
        float stripe = mod(diagonal - time * 40.0, 48.0);
        if (stripe < 4.0) {
            col.rgb += vec3(0.03); // subtle brightness bump
        }

        // snowflakes
        float snowAlpha = 0.0;
        for (int i = 1; i <= 30; i++) {
            float fi = float(i);
            float layer = mod(fi, 3.0) + 1.0;
            
            float speedY = 12.0 * layer;
            float speedX = sin(fi * 123.4) * 5.0;
            float startX = mod(fi * 173.1, love_ScreenSize.x);
            float startY = mod(fi * 231.3, love_ScreenSize.y);
            
            float x = mod(startX + time * speedX + sin(time + fi) * 8.0, love_ScreenSize.x);
            float y = mod(startY + time * speedY, love_ScreenSize.y);
            
            if (screen_coords.x >= x && screen_coords.x < x + layer &&
                screen_coords.y >= y && screen_coords.y < y + layer) {
                snowAlpha += 0.15 * layer;
            }
        }
        
        col.rgb += vec3(snowAlpha);

        return col;
    }
]]

cssBGShader = love.graphics.newShader[[
    mat2 rotate2d(float angle) {
        float c = cos(angle);
        float s = sin(angle);
        return mat2(
            c, -s, // Column 0
            s,  c  // Column 1
        );
    }

    extern number t;

    vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
    {    
        vec4 black = vec4(0, 0, 0, 1);
        vec4 blue = vec4(29/255.0, 43/255.0, 83/255.0, 1);

        vec2 coords = rotate2d(3.14/4) * screen_coords;
        coords.x += t*30;
        coords.y += t*20;

        if(mod(coords.x, 48) < 24 && mod(coords.y, 48) < 24 || mod(coords.x, 48) > 24 && mod(coords.y, 48) > 24) {
            return blue;
        }
        
        return black;
    }
]]

auroraShader = love.graphics.newShader[[
    extern number t;

    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc )
    {
        vec4 pixel = Texel(tex, tc);
        if (pixel.a == 0.0) return vec4(0.0);

        float safeTime = mod(t, 1000.0);
        float effectOpacity = 0.5; 
        float lum = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));

        // aurora
        float sheen = (sin(tc.x * 12.0 + safeTime * 1.2) + sin((tc.x + tc.y) * 8.0 - safeTime * 0.8)) * 0.5 + 0.5;
        vec3 addedLight = mix(vec3(0.0, 0.8, 0.6), vec3(0.6, 0.2, 0.8), sheen) * lum * 0.8;

        // sparkles
        vec2 st = tc * vec2(24.0, 13.5); 
        vec2 id = floor(st);
        
        float localTime = safeTime * 0.8 + random(id) * 100.0;
        float cycle = floor(localTime);
        
        // only calculate sparkles if the ice is bright + rng
        if (lum > 0.1 && random(id + cycle) > 0.96) {
            // Calculate a random offset between -0.4 and 0.4
            vec2 offset = (vec2(random(id + cycle + 12.0), random(id + cycle + 34.0)) - 0.5) * 0.8;
            
            float dist = length(fract(st) - 0.5 - offset);
            float glow = (0.015 / dist) * smoothstep(0.5, 0.1, dist);
            
            addedLight += vec3(0.6, 0.85, 1.0) * glow * sin(fract(localTime) * 3.14159); 
        }

        return vec4(pixel.rgb + (addedLight * effectOpacity), pixel.a) * color;
    }
]]

lavaShader = love.graphics.newShader[[
    extern number t;

    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc ) {
        vec4 pxl = Texel(tex, tc);
        float st = mod(t, 1000.0);
        float opacity = 0.4;

        // lava pool
        if (pxl.a == 0.0) {
            // Ambient air glow
            vec3 col = mix(vec3(0.05, 0.0, 0.02), vec3(0.6, 0.1, 0.0), smoothstep(0.0, 0.8, tc.y));
            float surf = 0.795 + sin(tc.x * 6.0 + st) * 0.02 + sin(tc.x * 12.0 - st * 0.75) * 0.01;
            
            if (tc.y > surf) { 
                // under lava surface
                float noise = (sin(tc.x * 20.0 + tc.y * 30.0 + st * 1.5) + sin((tc.x - tc.y) * 15.0 - st)) * 0.5 + 0.5;
                col = mix(vec3(0.7, 0.1, 0.0), vec3(1.0, 0.8, 0.0), noise);
                col += vec3(1.0, 0.9, 0.4) * smoothstep(0.06, 0.0, (tc.y - surf) / (1.0 - surf)); // Bright rim
            } else { 
                // embers
                vec2 est = tc * vec2(30.0, 16.0) + vec2(sin(st * 1.5 + tc.y * 5.0) * 0.5, st * 2.5);
                vec2 eid = floor(est);
                if (random(eid) > 0.95) {
                    float dist = length(fract(est) - 0.5);
                    float glow = (0.015 / dist) * smoothstep(0.5, 0.1, dist);
                    float twinkle = sin(st * 5.0 + random(eid) * 100.0) * 0.5 + 0.5;
                    col += vec3(1.0, 0.7, 0.2) * glow * smoothstep(0.3, 0.8, tc.y) * twinkle;
                }
            }
            return vec4(col * opacity, 1.0) * color;
        }
        float flicker = sin(st * 6.0) * 0.05 + sin(st * 3.5) * 0.05 + 0.9;
        vec3 addedLight = pxl.rgb * vec3(1.0, 0.3, 0.0) * smoothstep(0.2, 1.0, tc.y) * 0.6 * flicker;
        
        return vec4(pxl.rgb + (addedLight * opacity), pxl.a) * color;
    }
]]

spaceShader = love.graphics.newShader[[
    extern number t;

    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc ) {
        vec4 pxl = Texel(tex, tc);
        float st = mod(t, 1000.0);

        // deep space sky
        if (pxl.a == 0.0) {
            vec3 col = vec3(0.0, 0.0, 0.015); 
            
            // milky way nebula
            float wave = (sin(tc.x*5.0 + tc.y*4.0 - st*0.1) + sin(tc.x*-3.0 + tc.y*7.0 + st*0.08))*0.5 + 0.5;
            float neb = wave * smoothstep(0.1, 0.6, 1.0 - abs(tc.y - tc.x*0.6 - 0.1));
            col += (mix(vec3(0.05, 0.0, 0.15), vec3(0.0, 0.15, 0.2), wave) + vec3(0.2, 0.05, 0.15)*(neb*neb)) * 0.15;
            
            // grid stars
            vec2 id = floor(tc * vec2(40.0, 22.5));
            if (random(id) > 0.96) {
                float dist = length(fract(tc * vec2(40.0, 22.5)) - 0.5);
                float glow = (0.015 / dist) * smoothstep(0.5, 0.1, dist);
                vec3 starCol = mix(vec3(1.0, 0.8, 0.6), vec3(0.6, 0.8, 1.0), random(id + 1.0));
                col += starCol * glow * (sin(st*2.0 + random(id)*50.0)*0.3 + 0.7) * 0.5;
            }

            // scrolling clouds
            float cx = tc.x + st * 0.03;
            float noise = (sin(cx*8.0 + tc.y*12.0)*0.5 + sin(cx*15.0 - tc.y*20.0)*0.25 + sin(cx*30.0 + tc.y*25.0)*0.125)*0.5 + 0.5;
            float cAlpha = smoothstep(0.4, 0.7, noise) * smoothstep(0.4, 0.9, tc.y) * 0.85;
            col = mix(col, mix(vec3(0.02, 0.03, 0.05), vec3(0.12, 0.15, 0.25), noise), cAlpha);

            return vec4(col, 1.0) * color;
        }

        // opaque mountain shadows
        return vec4(pxl.rgb * vec3(0.2, 0.25, 0.4), pxl.a) * color;
    }
]]

sunsetShader = love.graphics.newShader[[
    extern number t;

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc ) {
        vec4 pxl = Texel(tex, tc);
        float st = mod(t, 1000.0);

        // clouds
        float cx = tc.x + st * 0.015;
        float noise = (sin(cx*8.0 + tc.y*40.0)*0.5 + sin(cx*14.0 - tc.y*70.0)*0.25 + sin(cx*24.0 + tc.y*100.0)*0.125)*0.5 + 0.5;
        float cAlpha = clamp(smoothstep(0.35, 0.65, noise) * smoothstep(0.6, 0.9, tc.y) + smoothstep(0.75, 1.0, tc.y)*0.9, 0.0, 1.0);
        vec3 cCol = mix(vec3(0.5, 0.15, 0.25), vec3(1.0, 0.9, 0.85), noise);

        // sky
        if (pxl.a == 0.0) {
            vec3 skyCol = mix(vec3(0.05, 0.02, 0.1), vec3(0.5, 0.15, 0.05), tc.y);
            return vec4(mix(skyCol, cCol, cAlpha), 1.0) * color;
        }

        // targeted mask for mountains
        vec3 m1 = vec3(20.0, 24.0, 30.0) / 255.0;
        vec3 m2 = vec3(33.0, 37.0, 48.0) / 255.0;
        float isMtn = smoothstep(0.06, 0.01, min(distance(pxl.rgb, m1), distance(pxl.rgb, m2)));
        
        vec3 tintBg = pxl.rgb * mix(vec3(1.0), vec3(0.8, 0.6, 0.5), isMtn);
        return vec4(mix(tintBg, cCol, cAlpha * isMtn), pxl.a) * color;
    }
]]

daytimeShader = love.graphics.newShader[[
    extern number t;

    // rng
    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    // 2d value noise
    float noise(vec2 st) {
        vec2 i = floor(st), f = fract(st);
        float a = random(i), b = random(i + vec2(1.0, 0.0));
        float c = random(i + vec2(0.0, 1.0)), d = random(i + vec2(1.0, 1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    // fbm
    float fbm(vec2 st) {
        float v = 0.0, a = 0.5;
        for (int i = 0; i < 3; i++) { v += a * noise(st); st *= 2.0; a *= 0.5; }
        return v;
    }

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc ) {
        vec4 pxl = Texel(tex, tc);
        float st = mod(t, 1000.0);

        // clouds
        vec2 uv = tc * vec2(6.0, 3.0);
        uv.x += st * 0.025; 
        float cloudShape = fbm(uv) - ((1.0 - tc.y) * 0.6); 
        float cAlpha = smoothstep(0.2, 0.45, cloudShape) * 0.85;
        vec3 cCol = mix(vec3(0.50, 0.65, 0.85), vec3(0.75, 0.85, 0.95), smoothstep(0.2, 0.55, cloudShape));

        // sky and background
        if (pxl.a == 0.0) {
            vec3 bgCol = mix(vec3(0.2, 0.5, 0.9), vec3(0.5, 0.75, 0.95), tc.y);
            
            // bg mountains
            float mx2 = tc.x * 5.0; 
            float mn2 = noise(vec2(mx2, 0.0))*0.5 + noise(vec2(mx2*2.5, 0.0))*0.25 + noise(vec2(mx2*5.0, 0.0))*0.125;
            float mh2 = 0.08 + mn2 * 0.12; 
            bgCol = mix(bgCol, mix(vec3(0.50, 0.45, 0.65), vec3(0.65, 0.70, 0.85), (1.0 - tc.y) / mh2), step(1.0 - tc.y, mh2));

            // fg mountains
            float mx1 = tc.x * 7.0; 
            float mn1 = noise(vec2(mx1, 100.0))*0.5 + noise(vec2(mx1*2.5, 100.0))*0.25 + noise(vec2(mx1*5.0, 100.0))*0.125;
            float mh1 = 0.04 + mn1 * 0.14; 
            bgCol = mix(bgCol, mix(vec3(0.35, 0.20, 0.40), vec3(0.60, 0.50, 0.70), (1.0 - tc.y) / mh1), step(1.0 - tc.y, mh1));

            return vec4(mix(bgCol, cCol, cAlpha), 1.0) * color;
        }

        // foreground terrain fog
        vec3 m1 = vec3(20.0, 24.0, 30.0) / 255.0, m2 = vec3(33.0, 37.0, 48.0) / 255.0;
        float isMtn = smoothstep(0.06, 0.01, min(distance(pxl.rgb, m1), distance(pxl.rgb, m2)));
        vec3 tintBg = mix(pxl.rgb, mix(pxl.rgb, vec3(0.6, 0.75, 0.9), 0.4), isMtn); 
        
        return vec4(mix(tintBg, cCol, cAlpha * isMtn * 0.3), pxl.a) * color;
    }
]]

amazonShader = love.graphics.newShader[[
    extern number t;

    // rng
    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    // 2d noise
    float noise(vec2 st) {
        vec2 i = floor(st), f = fract(st);
        float a = random(i), b = random(i + vec2(1.0, 0.0));
        float c = random(i + vec2(0.0, 1.0)), d = random(i + vec2(1.0, 1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    // fbm
    float fbm(vec2 st) {
        float v = 0.0, a = 0.5;
        for (int i = 0; i < 3; i++) { v += a * noise(st); st *= 2.0; a *= 0.5; }
        return v;
    }

    // birds
    float drawBird(vec2 uv, vec2 center, float time, float scale) {
        vec2 p = (uv - center) * scale;
        float flap = sin(time * (5.0 + scale * 0.05) + scale) * 0.4 + 0.6;
        float wings = abs(p.x) * 2.5;
        return smoothstep(0.08, 0.02, abs(p.y + wings * wings * flap)) * smoothstep(0.4, 0.1, abs(p.x));
    }

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc ) {
        vec4 pxl = Texel(tex, tc);
        if (pxl.a != 0.0) return pxl * color; // fg early exit

        float st = mod(t, 1000.0);
        
        // sky gradient
        vec3 bgCol = mix(vec3(17.0, 29.0, 53.0)/255.0, vec3(0.0), smoothstep(0.3, 1.0, tc.y));

        // clouds
        vec2 uv = tc * vec2(1.5, 10.0);
        uv.x += st * 0.01; 
        float cAlpha = smoothstep(0.5, 0.53, fbm(uv) - (tc.y * 0.5)); 
        bgCol = mix(bgCol, vec3(29.0, 43.0, 83.0)/255.0, cAlpha);

        // birds
        float birds = drawBird(tc, vec2(fract(0.2 + st * 0.06), 0.2), st, 40.0) +
                      drawBird(tc, vec2(fract(0.6 + st * 0.07), 0.28), st, 30.0) +
                      drawBird(tc, vec2(fract(0.9 + st * 0.04), 0.15), st, 50.0) +
                      drawBird(tc, vec2(fract(0.4 + st * 0.05), 0.35), st, 35.0);
                      
        bgCol = mix(bgCol, vec3(18.0, 83.0, 89.0)/255.0, clamp(birds, 0.0, 1.0));

        return vec4(bgCol, 1.0) * color;
    }
]]

steampunkShader = love.graphics.newShader[[
    extern number t;

    // rng
    float random(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
    }

    // 2d noise
    float noise(vec2 st) {
        vec2 i = floor(st), f = fract(st);
        float a = random(i), b = random(i + vec2(1.0, 0.0));
        float c = random(i + vec2(0.0, 1.0)), d = random(i + vec2(1.0, 1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    // fbm
    float fbm(vec2 st) {
        float v = 0.0, a = 0.5;
        for (int i = 0; i < 3; i++) { v += a * noise(st); st *= 2.0; a *= 0.5; }
        return v;
    }

    vec4 effect( vec4 color, Image tex, vec2 tc, vec2 sc ) {
        vec4 pxl = Texel(tex, tc);
        if (pxl.a != 0.0) return pxl * color; // fg early exit

        float st = mod(t, 1000.0);
        
        // dark grimy bg
        vec3 bg = mix(vec3(0.04, 0.03, 0.03), vec3(0.10, 0.08, 0.07), fbm(tc * vec2(10.0, 6.0)));

        // x pipes
        float rx = random(vec2(floor(tc.x * 15.0), floor(tc.x * 15.0) + 0.5)); 
        float tx = mix(0.75, 0.88, rx), px = tc.x * 15.0 + rx * 100.0;
        float vp = smoothstep(tx, tx + 0.03, sin(px)) * step(rx, 0.7);
        float gx = clamp((-cos(px) / sqrt(1.0 - tx * tx)) * 0.5 + 0.5, 0.0, 1.0);
        vec3 cx = (vec3(0.15, 0.09, 0.10) * mix(0.35, 0.75, gx) + vec3(0.08, 0.05, 0.06) * pow(gx, 2.0)) * mix(1.0, 0.15, rx);

        // y pipes
        float ry = random(vec2(floor(tc.y * 15.0), floor(tc.y * 15.0) + 10.5));
        float ty = mix(0.75, 0.88, ry), py = tc.y * 15.0 + ry * 100.0;
        float hp = smoothstep(ty, ty + 0.03, sin(py)) * step(ry, 0.7);
        float gy = clamp((cos(py) / sqrt(1.0 - ty * ty)) * 0.5 + 0.5, 0.0, 1.0);
        vec3 cy = (vec3(0.15, 0.09, 0.10) * mix(0.35, 0.75, gy) + vec3(0.08, 0.05, 0.06) * pow(gy, 2.0)) * mix(1.0, 0.15, ry);

        // layering
        float xf = step(rx, ry); 
        bg = mix(bg, mix(cx, cy, xf), mix(vp, hp, xf)); // back pipe layer
        bg = mix(bg, mix(cy, cx, xf), mix(hp, vp, xf)); // front pipe layer

        // shapes & fog
        bg = mix(bg, vec3(0.04, 0.035, 0.03), smoothstep(0.4, 0.5, fbm(tc * vec2(3.0, 1.5) + vec2(100.0, 50.0))) * 0.3);
        float sa = smoothstep(0.4, 0.7, fbm(tc * vec2(2.0, 1.0) + vec2(st * 0.03, st * 0.015))) * smoothstep(1.0, 0.4, tc.y);
        bg = mix(bg, vec3(0.46, 0.41, 0.38), sa * 0.6);

        // posterize
        float levels = 48.0; 
        bg = floor(bg * levels + 0.5) / levels;

        return vec4(bg, 1.0) * color;
    }
]]