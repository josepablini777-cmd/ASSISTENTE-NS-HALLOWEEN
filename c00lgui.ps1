# c00lgui v6.66 - panel lanzador con skins de asistentes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# el panel mide su propio escalado de pantalla para que nada se corte
try {
    Add-Type -Namespace C00l -Name Dpi -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][C00l.Dpi]::SetProcessDPIAware()
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()
# caja del bocadillo: puede recibir la rueda del ratón para leer textos largos
try {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
public class CajaTexto : System.Windows.Forms.Panel {
    public CajaTexto() {
        SetStyle(System.Windows.Forms.ControlStyles.Selectable | System.Windows.Forms.ControlStyles.SupportsTransparentBackColor | System.Windows.Forms.ControlStyles.OptimizedDoubleBuffer | System.Windows.Forms.ControlStyles.AllPaintingInWmPaint | System.Windows.Forms.ControlStyles.UserPaint, true);
        TabStop = false;
    }
}
'@
} catch {}

# TAMAÑO DEL PANEL: 1.0 = normal, 1.2 = un poco más grande, 1.5 = grande
$Tamano = 1.2
$gDpi = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$script:dpiBase = $gDpi.DpiX / 96.0
$script:K = [float]($script:dpiBase * $Tamano)
$gDpi.Dispose()
# fuentes en píxeles: Fnt para controles (ya escalada), FntP para dibujos (los escala ScaleTransform)
function Fnt($a) {
    $st = if ($a.Count -ge 3) { $a[2] } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font((Familia ([string]$a[0])), [float]($a[1] * 96 / 72 * $script:K), $st, [System.Drawing.GraphicsUnit]::Pixel)
}
function FntP($a) {
    $st = if ($a.Count -ge 3) { $a[2] } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font((Familia ([string]$a[0])), [float]($a[1] * 96 / 72), $st, [System.Drawing.GraphicsUnit]::Pixel)
}
# fuentes que vienen con las skins (las de Mewgenics) o las de Windows
$script:fuentesPriv = @{}
function Familia($n) {
    if ($script:fuentesPriv.ContainsKey($n)) { return $script:fuentesPriv[$n] }
    try { return (New-Object System.Drawing.FontFamily($n)) } catch { return [System.Drawing.FontFamily]::GenericSansSerif }
}
function Escalar($ctl) { $ctl.Scale((New-Object System.Drawing.SizeF($script:K, $script:K))) }
# cualquier error interno se convierte en un glitch/mensaje del panel en vez de una ventana de error
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)

$Raiz = $PSScriptRoot
$script:pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($ttf in @('skins\kaijus\edmund.ttf', 'skins\kaijus\tika.ttf')) { $r = Join-Path $Raiz $ttf; if (Test-Path $r) { try { $script:pfc.AddFontFile($r) } catch {} } }
foreach ($fam in $script:pfc.Families) { $script:fuentesPriv[$fam.Name] = $fam; $script:fuentesPriv[($fam.Name -replace ' Regular$', '')] = $fam }
$ArchivoSkin = Join-Path $Raiz 'skin.txt'
$Rnd = New-Object System.Random
$script:dia = (Get-Date).DayOfYear

# ================= AJUSTES (se guardan en ajustes.txt) =================
$ArchivoAjustes = Join-Path $Raiz 'ajustes.txt'
$script:aj = [ordered]@{
    Sonido = $true; Volumen = 100; Invitados = $true; Intros = $true; Charla = 'normal'
    Encima = $false; Tamano = [double]$Tamano; Opacidad = 100; Posicion = $true; Inicio = $false; X = ''; Y = ''
    Guia = $false   # si ya se ha visto la guía del panda
    Epilepsia = $false   # modo seguro: sin destellos, parpadeos, temblores ni intros (ver Sin-Destellos)
    KnightVictorias = 0   # victorias en el minijuego del Roaring Knight
    AngelaDia = 1   # día de Lobotomy Corporation en la skin de Angela (sube al completar la cuota de energía)
}
function Cargar-Ajustes {
    if (-not (Test-Path $ArchivoAjustes)) { return }
    foreach ($l in (Get-Content $ArchivoAjustes -Encoding UTF8)) {
        if ($l -notmatch '^\s*(\w+)\s*=\s*(.*)$') { continue }
        $c = $Matches[1]; $v = $Matches[2].Trim()
        if (-not $script:aj.Contains($c)) { continue }
        $act = $script:aj[$c]
        if ($act -is [bool]) { $script:aj[$c] = ($v -eq 'si') }
        elseif ($act -is [int]) { $n = 0; if ([int]::TryParse($v, [ref]$n)) { $script:aj[$c] = $n } }
        elseif ($act -is [double]) { $d = 0.0; if ([double]::TryParse($v, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { $script:aj[$c] = $d } }
        else { $script:aj[$c] = $v }
    }
}
function Guardar-Ajustes {
    $l = foreach ($c in $script:aj.Keys) {
        $v = $script:aj[$c]
        if ($v -is [bool]) { $v = $(if ($v) { 'si' } else { 'no' }) } elseif ($v -is [double]) { $v = $v.ToString([Globalization.CultureInfo]::InvariantCulture) }
        "$c = $v"
    }
    try { Set-Content -Path $ArchivoAjustes -Value $l -Encoding UTF8 } catch {}
}
Cargar-Ajustes
$script:K = [float]($script:dpiBase * $script:aj.Tamano)

# ================= BOTONES =================
# Estos son los botones de serie. Cada persona puede cambiar el orden y añadir los suyos desde el panel
# (Ajustes > Editar botones): se guardan en botones.txt y, si ese archivo existe, se usan en vez de esta lista.
# Nombre = texto del botón | Abrir = programa, archivo, carpeta o URL | Web = (opcional) URL si el programa no está instalado
$BotonesDeSerie = @(
    @{ Nombre = 'YouTube';       Abrir = 'https://www.youtube.com' }
    @{ Nombre = 'Word';          Abrir = 'winword.exe';  Web = 'https://www.office.com/launch/word' }
    @{ Nombre = 'Excel';         Abrir = 'excel.exe';    Web = 'https://www.office.com/launch/excel' }
    @{ Nombre = 'PowerPoint';    Abrir = 'powerpnt.exe'; Web = 'https://www.office.com/launch/powerpoint' }
    @{ Nombre = 'Outlook';       Abrir = 'outlook.exe';  Web = 'https://outlook.live.com' }
    @{ Nombre = 'OneNote';       Abrir = 'onenote.exe';  Web = 'https://www.onenote.com/notebooks' }
    @{ Nombre = 'Access';        Abrir = 'msaccess.exe' }
    @{ Nombre = 'Publisher';     Abrir = 'mspub.exe' }
    @{ Nombre = 'Teams';         Abrir = 'ms-teams:';    Web = 'https://teams.microsoft.com' }
    @{ Nombre = 'OneDrive';      Abrir = 'https://onedrive.live.com' }
    @{ Nombre = 'Office Web';    Abrir = 'https://www.office.com' }
    @{ Nombre = 'Bloc de notas'; Abrir = 'notepad.exe' }
    @{ Nombre = 'Calculadora';   Abrir = 'calc.exe' }
    @{ Nombre = 'Explorador';    Abrir = 'explorer.exe' }
    @{ Nombre = 'CMD';           Abrir = 'cmd.exe' }
    @{ Nombre = 'GitHub';        Abrir = 'https://github.com' }
    @{ Nombre = 'Wikipedia';     Abrir = 'https://es.wikipedia.org' }
)

# botones.txt: una línea por botón, en el orden del panel:   Nombre | qué abre | web (opcional)
# las líneas que empiezan por # son comentarios
$ArchivoBotones = Join-Path $Raiz 'botones.txt'
function Copiar-Botones($lista) { return @($lista | ForEach-Object { @{ Nombre = [string]$_.Nombre; Abrir = [string]$_.Abrir; Web = [string]$_.Web } }) }
function Cargar-Botones {
    if (-not (Test-Path $ArchivoBotones)) { return (Copiar-Botones $BotonesDeSerie) }
    $lista = New-Object System.Collections.ArrayList
    foreach ($l in (Get-Content $ArchivoBotones -Encoding UTF8)) {
        if ($l -match '^\s*(#|$)') { continue }
        $p = @($l -split '\|' | ForEach-Object { $_.Trim() })
        if ($p.Count -lt 2 -or -not $p[0] -or -not $p[1]) { continue }
        [void]$lista.Add(@{ Nombre = $p[0]; Abrir = $p[1]; Web = $(if ($p.Count -ge 3) { $p[2] } else { '' }) })
    }
    if ($lista.Count -eq 0) { return (Copiar-Botones $BotonesDeSerie) }
    return @($lista)
}
function Guardar-Botones($lista) {
    $l = @(
        '# Botones del panel c00lgui, en orden. Una línea por botón:'
        '#   Nombre | qué abre (web, programa, archivo o carpeta) | web si el programa no está instalado (opcional)'
        '# Se puede cambiar desde el panel: Ajustes > Editar botones. Borra este archivo para volver a los de serie.'
        ''
    ) + @($lista | ForEach-Object { if ($_.Web) { "$($_.Nombre) | $($_.Abrir) | $($_.Web)" } else { "$($_.Nombre) | $($_.Abrir)" } })
    try { Set-Content -Path $ArchivoBotones -Value $l -Encoding UTF8; return $true } catch { return $false }
}
$Botones = Cargar-Botones

# ================= SKINS =================
# CÓMO AÑADIR UNA SKIN NUEVA
#   1. Copia el bloque de una skin parecida dentro de $Skins (más abajo) y cámbiale el nombre,
#      los colores y el 'Estilo' (una palabra corta y nueva, por ejemplo 'punk').
#      Las imágenes y sonidos van en una carpeta propia dentro de skins\.
#      Sus frases van en dialogos\<nombre de la skin>.json (copia el de una skin parecida).
#   2. Ponla en su grupo en $GruposSkins (justo después de $Skins) para que salga en el menú Skins.
#   3. Busca en el archivo un estilo parecido (por ejemplo 'punk') y añade el tuyo en los mismos sitios:
#      Fondo-Escena (fondo), Pintar-Burbuja (bocadillo), Pintar-Boton (botones), la lista de estilos
#      del Paint de la ventana y su switch (lo que se mueve), Lanzar (al abrir una app), Clic-Actor
#      (clic en el personaje), Efecto-Entrada (su intro), el temporizador de frases sueltas ($idleTimer),
#      el de animación ($ambTimer) y Abrir-Invitado / Pintar-Invitado (su ventanita en las discusiones).
#   4. Para que las demás opinen de ella, añade su nombre en 'AlVenirDe' y 'Opina' del JSON de cada skin
#      (carpeta dialogos), y escribe charlas nuevas en dialogos\_charlas.json.
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

# ---- datos de Enfosi (de sus wikis): los 7 Glaggles en el orden de sus oleadas ----
$EnfosiTipos = @('giggler', 'gazo', 'gloober', 'gembo', 'cheerer', 'gleeber', 'glaaber')
$EnfosiNombre = @{ giggler = 'Giggler'; gazo = 'Gazo'; gloober = 'Gloober'; gembo = 'Gembo'; cheerer = 'Cheerer'; gleeber = 'Gleeber'; glaaber = 'Glaaber'; gergro = 'Gergro'; borgack = 'Borgack'; risio = 'Risio' }
# velocidad al andar: los Gleebers son los más rápidos, los Cheerers corren mucho y los Glaabers son los más lentos
$EnfosiVel = @{ giggler = 1.6; gazo = 1.5; gloober = 1.25; gembo = 1.15; cheerer = 2.2; gleeber = 2.6; glaaber = 0.9 }
# clics que aguantan después de descubrirlos (según su vida en el juego)
$EnfosiVida = @{ giggler = 2; gazo = 2; gloober = 3; gembo = 3; cheerer = 2; gleeber = 3; glaaber = 5 }
# daño a la estatua de cada Enphosian (el del juego)
$EnfosiDanio = @{ giggler = 100; gazo = 40; gloober = 30; gembo = 100; cheerer = 500; gleeber = 150; glaaber = 200 }
# lo que dice el juego de cada uno (traducido)
$EnfosiTexto = @{
    giggler = '¡Un Giggler alegre! ¡Mira su sonrisa!'
    gazo    = '¡Un Gazo chiflado! ¡Un experto en tecnología y en disparar de lejos!'
    gloober = '¡Un Gloober tontorrón! ¡Ayuda a los que lo necesitan!'
    gembo   = '¡Un Gembo majo! ¡Un soldado con explosivos peligrosos!'
    cheerer = '¡Un Cheerer juguetón! ¿Qué habrá en esa caja de regalo?'
    gleeber = '¡Un Gleeber simpático! ¿Vamos a patinar?'
    glaaber = '¡Un Glaaber espeluznante! ¡Cuidado con su porra!'
}
# los cuatro fallos de un disfraz, en el orden de las imágenes de la wiki
$EnfosiFallo = @{ 1 = 'tenía la piel de otro color'; 2 = 'llevaba un símbolo falso en la camiseta'; 3 = 'no llevaba símbolo en la camiseta'; 4 = 'no tenía cara' }
# jefes tras las oleadas 2, 4 y 6: imagen, nombre, clics que aguanta, frase
$EnfosiJefes = @{
    2 = @('gergro', 'Gergro', 8, '¡JEFE: GERGRO! Un Giggler acróbata con pistola y bate. Dale clics hasta tumbarlo.')
    4 = @('borgack', 'Borgack', 10, '¡JEFE: BORGACK! Vuela con jetpack y tira dinamita. ¡Que no llegue a la estatua!')
    6 = @('risio', 'Risio', 12, '¡JEFE: RISIO! Usa las armas de la tienda contra ti. Es el último jefe.')
}
$EnfosiPoses = @{ gergro = 'skins\enfosi\gergro.png'; borgack = 'skins\enfosi\borgack.png'; risio = 'skins\enfosi\risio.png' }
foreach ($t in $EnfosiTipos) {
    $EnfosiPoses[$t] = "skins\enfosi\$t.png"; $EnfosiPoses["$($t)_e"] = "skins\enfosi\$($t)_enfosi.png"
    for ($i = 1; $i -le 4; $i++) { $EnfosiPoses["$t$i"] = "skins\enfosi\$($t)_falso$i.png" }
}

$Skins = [ordered]@{
    # ================================================================ c00lgui
    'c00lgui' = @{
        Estilo = 'hacker'; Titulo = 'c00lgui'; Sub = 'v6.66'; Alto = 312
        Fondo = (C 0 0 0); Borde = (C 255 0 0); Sombra = (C 90 0 0)
        TituloColor = (C 255 0 0); SubColor = (C 140 0 0)
        BtnFondo = (C 0 0 0); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 40 40); BtnBorde = (C 255 0 0); BtnBordeAncho = 1
        BtnHover = (C 45 0 0); BtnPress = (C 255 0 0); BarraBtnTexto = (C 255 0 0)
        StatusColor = (C 255 0 0); Fuente = 'Arial'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 2
    }
    # ================================================================ SeaDrive (página web)
    'SeaDrive' = @{
        Estilo = 'web'; Titulo = 'SeaDrive'; Sub = 'virtual assistant  ·  HowTo'; Alto = 344; Top = 32
        Url = 'https://www.seadrive.howto/asistente'
        Fondo = (C 236 247 255); Borde = (C 40 130 200); Barra1 = (C 110 200 245); Barra2 = (C 40 130 200)
        TituloColor = (C 255 255 255); SubColor = (C 255 210 40)
        BtnFondo = (C 255 198 26); BtnTexto = (C 20 20 20); BtnTextoHover = (C 20 20 20); BtnBorde = (C 20 20 20); BtnBordeAncho = 1
        BtnHover = (C 140 220 60); BtnPress = (C 40 130 200); BarraBtnTexto = (C 20 20 20)
        StatusColor = (C 30 30 30); Fuente = 'Segoe UI'; FuenteTitulo = 'Segoe UI Black'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\seadrive\seadrive.gif'
        Pb = @(410, 98, 190, 150); PbFondo = (C 255 255 255); PbBorde = $true
        Burbuja = @(410, 254, 190, 70); BurFondo = (C 255 255 255); BurTexto = (C 20 20 20); BurFuente = 'Segoe UI'
    }
    # ================================================================ Static Miku (tele de dibujos)
    'Static Miku' = @{
        Estilo = 'tele'; Titulo = 'STATIC'; Sub = 'miku  ·  flavor foley'; Alto = 312
        Fondo = (C 232 38 28); Borde = (C 0 0 0); Sombra = (C 0 0 0)
        TituloColor = (C 255 225 50); SubColor = (C 90 225 245)
        Paleta = @((C 90 220 245), (C 255 225 50), (C 255 105 205), (C 120 235 95), (C 255 165 45))
        BtnFondo = (C 90 220 245); BtnTexto = (C 0 0 0); BtnTextoHover = (C 0 0 0); BtnBorde = (C 0 0 0); BtnBordeAncho = 3
        BtnHover = (C 255 255 255); BtnPress = (C 60 45 190); BarraBtnTexto = (C 0 0 0)
        StatusColor = (C 255 255 255); Fuente = 'Comic Sans MS'; FuenteTitulo = 'Comic Sans MS'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\staticmiku\miku.gif'; GifClic = 'skins\staticmiku\miku_feliz.gif'; GifRaro = 'skins\staticmiku\miku_ojos.gif'
        Pb = @(414, 76, 182, 132); PbFondo = (C 0 0 0); PbBorde = $false
        Burbuja = @(404, 240, 202, 56); BurFondo = (C 255 255 255); BurTexto = (C 20 20 20); BurFuente = 'Comic Sans MS'
    }
    # ================================================================ Guillotina (Mewgenics)
    'Guillotina' = @{
        Estilo = 'mew'; Titulo = 'GUILLOTINA'; Sub = 'house boss  ·  mewgenics'; Alto = 312
        Fondo = (C 46 33 40); Borde = (C 20 14 16)
        TituloColor = (C 240 228 200); SubColor = (C 215 75 60)
        BtnFondo = (C 245 236 212); BtnTexto = (C 25 20 22); BtnTextoHover = (C 25 20 22); BtnBorde = (C 25 20 22); BtnBordeAncho = 2
        BtnHover = (C 215 80 65); BtnPress = (C 120 25 25); BarraBtnTexto = (C 25 20 22)
        StatusColor = (C 240 228 200); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\guillotina\g_idle.gif'
        FondoImg = 'skins\guillotina\callejon.jpg'
        # intro (imágenes del juego): las fotos que pasan rápido, el callejón de la jefa, ella, el cartel y el marco de cables
        IntroFotos = @('skins\guillotina\intro_callejon1.jpg', 'skins\guillotina\intro_callejon2.jpg', 'skins\guillotina\intro_callejon3.jpg', 'skins\guillotina\cementerio.jpg', 'skins\guillotina\callejon.jpg')
        IntroJefa = 'skins\guillotina\intro_jefa.jpg'; IntroGuillotina = 'skins\guillotina\intro_guillotina.png'
        IntroCartel = 'skins\guillotina\intro_cartel.png'; IntroMarco = 'skins\guillotina\intro_marco.png'
        Actores = @(
            @{ Id = 'G'; Gif = 'skins\guillotina\g_idle.gif'; Rect = @(432, 66, 316, 190)
               Extra = @{ furiosa = 'skins\guillotina\g_furiosa.gif'; clic = 'skins\guillotina\g_enfado.gif'; inhala = 'skins\guillotina\g_inhala.gif'; inhalaf = 'skins\guillotina\g_inhala_f.gif'
                          lanza = 'skins\guillotina\g_lanza.gif'; barriga = 'skins\guillotina\g_barriga.gif'; digiere = 'skins\guillotina\g_digiere.gif'; herida = 'skins\guillotina\g_herida.gif' } }
        )
        Cartel = 'skins\guillotina\cartel_g.png'
        Sonidos = @{
            intro = @('skins\guillotina\s_enfado_sfx.wav'); furia = @('skins\guillotina\s_enfado.wav'); radio = @('skins\guillotina\radio_intro.wav')
            golpe = @('skins\guillotina\s_golpe1.wav', 'skins\guillotina\s_golpe2.wav', 'skins\guillotina\s_golpe3.wav'); golpef = @('skins\guillotina\s_golpef1.wav', 'skins\guillotina\s_golpef2.wav')
            comer = @('skins\guillotina\s_inhala1.wav', 'skins\guillotina\s_inhala2.wav'); digiere = @('skins\guillotina\s_digiere.wav'); lanza = @('skins\guillotina\s_lanza.wav')
            barriga = @('skins\guillotina\s_barriga.wav'); muere = @('skins\guillotina\s_muere.wav'); mordisco = @('skins\guillotina\s_mordisco.wav'); paso = @('skins\guillotina\s_paso.wav')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 250 244 228); BurTexto = (C 30 20 22); BurFuente = 'TikaFont Adjusted'
    }
    # ================================================================ Angela (Lobotomy Corporation)
    # La IA asistente de L Corp, en su sala de monitores. Ficha en lore\personajes\Angela.md.
    # Cada app es un trabajo con una anomalía (energía, cuota del día, Fusión de Qliphoth) y a veces hay brechas de contención
    # que se reprimen haciendo clic en el monitor. Música oficial del juego: Neutral01-04 y las alarmas First/Second/Third Warning.
    'Angela' = @{
        Estilo = 'lobo'; Titulo = 'ANGELA'; Sub = 'lobotomy corporation  ·  face the fear'; Alto = 320
        Fondo = (C 10 13 18); Borde = (C 255 170 40); Acento = (C 255 170 40)
        TituloColor = (C 236 240 244); SubColor = (C 255 176 50)
        BtnFondo = (C 16 22 30); BtnTexto = (C 220 232 240); BtnTextoHover = (C 12 14 18); BtnBorde = (C 255 170 40); BtnBordeAncho = 2
        BtnHover = (C 255 176 50); BtnPress = (C 80 210 200); BarraBtnTexto = (C 220 232 240)
        StatusColor = (C 220 232 240); Fuente = 'Bahnschrift'; FuenteTitulo = 'Bahnschrift'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\angela\busto.png'; FondoImg = 'skins\angela\fondo.jpg'
        FiltroImg = 'skins\angela\filtro.jpg'; IntroDia = 'skins\angela\intro_dia.jpg'
        # Angela de cuerpo entero con sus expresiones del juego (ojos cerrados casi siempre; los abre cuando va en serio)
        Actores = @(
            @{ Id = 'A'; Gif = 'skins\angela\a_angela.png'; Rect = @(590, 46, 170, 280); Respira = $true
               Extra = @{ habla = 'skins\angela\a_habla.png'; sorpresa = 'skins\angela\a_sorpresa.png'; sonrie = 'skins\angela\a_sonrie.png'; risa = 'skins\angela\a_risa.png'
                          molesta = 'skins\angela\a_molesta.png'; molesta_habla = 'skins\angela\a_molesta_habla.png'
                          abiertos = 'skins\angela\a_abiertos.png'; abiertos_habla = 'skins\angela\a_abiertos_habla.png'
                          enfado = 'skins\angela\a_enfado.png'; enfado_habla = 'skins\angela\a_enfado_habla.png' } }
        )
        # anomalías que pueden romper la contención (retrato del juego, nivel de riesgo y clics para reprimirlas)
        Anomalias = @(
            @{ Nombre = 'Punishing Bird'; Codigo = 'O-02-56'; Riesgo = 'TETH'; Vida = 3; Img = 'skins\angela\an_castigo.jpg' }
            @{ Nombre = 'Scorched Girl'; Codigo = 'F-01-02'; Riesgo = 'TETH'; Vida = 3; Img = 'skins\angela\an_cerilla.jpg' }
            @{ Nombre = 'Der Freischütz'; Codigo = 'F-01-69'; Riesgo = 'HE'; Vida = 4; Img = 'skins\angela\an_freischutz.jpg' }
            @{ Nombre = 'Queen of Hatred'; Codigo = 'O-01-04'; Riesgo = 'WAW'; Vida = 5; Img = 'skins\angela\an_reina.jpg' }
            @{ Nombre = 'Big Bird'; Codigo = 'O-02-40'; Riesgo = 'WAW'; Vida = 5; Img = 'skins\angela\an_pajaro.jpg' }
        )
        # los 4 tipos de trabajo del juego y los 3 resultados (con sus iconos)
        Trabajos = @(@('instinto', 'Instinto'), @('percepcion', 'Percepción'), @('apego', 'Apego'), @('represion', 'Represión'))
        Sonidos = @{
            pebox = @('skins\angela\pebox.wav'); trabajo = @('skins\angela\trabajo.wav'); alarma = @('skins\angela\alarma.wav'); golpe = @('skins\angela\golpe.wav')
            reprimida = @('skins\angela\reprimida.wav'); fin = @('skins\angela\fin.wav'); filtro = @('skins\angela\filtro.wav'); fusion = @('skins\angela\fusion.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 16 22 30); BurTexto = (C 220 232 240); BurFuente = 'Bahnschrift'
    }
    # ================================================================ Mikaela (PURSUITCORE)
    'Mikaela' = @{
        Estilo = 'mlg'; Titulo = ''; TituloImg = 'skins\mikaela\placa.png'; Sub = 'THE MVP  ·  PURSUITCORE'; Alto = 312
        Fondo = (C 30 30 60); Borde = (C 0 255 0)
        TituloColor = (C 255 255 255); SubColor = (C 191 239 255)
        BtnFondo = (C 12 12 24); BtnTexto = (C 255 255 255); BtnTextoHover = (C 0 0 0); BtnBorde = (C 0 255 0); BtnBordeAncho = 2
        BtnHover = (C 0 230 0); BtnPress = (C 229 45 45); BarraBtnTexto = (C 0 255 0)
        StatusColor = (C 191 239 255); Fuente = 'Arial Black'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 2
        Gif = 'skins\mikaela\retrato.png'; GifClic = 'skins\mikaela\peligro.png'
        Sonidos = @{
            apuntar = @('skins\mikaela\apuntar.mp3'); carga = @('skins\mikaela\carga.mp3'); sobrecarga = @('skins\mikaela\sobrecarga.mp3')
            disparo = @('skins\mikaela\disparo.mp3'); disparoMax = @('skins\mikaela\disparo_max.mp3')
            humo = @('skins\mikaela\humo.mp3'); dew = @('skins\mikaela\dew.mp3')
        }
        Pb = @(410, 62, 190, 150); PbFondo = (C 0 0 0); PbBorde = $false
        Burbuja = @(410, 232, 190, 64); BurFondo = (C 8 8 16); BurTexto = (C 0 255 0); BurFuente = 'Arial'
    }
    # ================================================================ Zodiac (Mewgenics)
    'Zodiac' = @{
        Estilo = 'oeste'; Titulo = 'ZODIAC'; Sub = 'the desert  ·  mewgenics'; Alto = 312
        Fondo = (C 236 196 130); Borde = (C 60 34 18)
        TituloColor = (C 250 225 170); SubColor = (C 240 160 70)
        BtnFondo = (C 128 80 42); BtnTexto = (C 250 236 205); BtnTextoHover = (C 250 236 205); BtnBorde = (C 55 32 16); BtnBordeAncho = 2
        BtnHover = (C 176 112 56); BtnPress = (C 200 60 30); BarraBtnTexto = (C 250 236 205)
        StatusColor = (C 250 236 205); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\zodiac\z_idle.gif'
        FondoImg = 'skins\zodiac\desierto.jpg'; IntroImg = 'skins\zodiac\coche.jpg'
        Actores = @(
            @{ Id = 'Z'; Gif = 'skins\zodiac\z_idle.gif'; Rect = @(476, 62, 240, 192)
               Extra = @{ clic = 'skins\zodiac\z_disparo.gif'; vacio = 'skins\zodiac\z_vacio.gif'; recarga = 'skins\zodiac\z_recarga.gif'; pose = 'skins\zodiac\z_pose.gif'; muere = 'skins\zodiac\z_muere.gif' } }
        )
        Cartel = 'skins\zodiac\cartel_z.png'
        Sonidos = @{
            loco = @('skins\zodiac\loco1.wav', 'skins\zodiac\loco2.wav', 'skins\zodiac\loco3.wav', 'skins\zodiac\loco4.wav')
            bang = @('skins\zodiac\s_bang.wav'); grito = @('skins\zodiac\s_grito1.wav', 'skins\zodiac\s_grito2.wav', 'skins\zodiac\s_grito3.wav')
            recarga = @('skins\zodiac\s_recarga.wav'); recargav = @('skins\zodiac\s_recargav1.wav', 'skins\zodiac\s_recargav2.wav')
            vacio = @('skins\zodiac\s_vacio.wav'); dolor = @('skins\zodiac\s_dolor1.wav', 'skins\zodiac\s_dolor2.wav'); muere = @('skins\zodiac\s_muere.wav')
            aparece = @('skins\zodiac\s_aparece.wav'); viento = @('skins\zodiac\viento.wav')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 245 230 196); BurTexto = (C 60 34 18); BurFuente = 'TikaFont Adjusted'
    }
    # ================================================================ Velvet (Gunsaw)
    # Una de las 14 especies de Gunsaw (Orsoniks): araña de voz maternal que atrae a los demás para cenárselos. Ficha en lore\personajes\Velvet.md.
    # Su guarida: telaraña, capullos colgando, SEDA para escupir telarañas a los botones, HAMBRE y CONFIANZA (el "abracito").
    # Música: "Night of the Creeps" de Karl Casey (suena en Gunsaw; White Bat Audio, libre de derechos).
    'Velvet' = @{
        Estilo = 'arana'; Titulo = 'VELVET'; Sub = 'arachnid  ·  14/14 species unlocked  ·  gunsaw'; Alto = 320
        Fondo = (C 16 8 14); Borde = (C 200 24 44); Acento = (C 230 30 50)
        TituloColor = (C 236 228 232); SubColor = (C 230 60 80)
        BtnFondo = (C 26 12 20); BtnTexto = (C 236 228 232); BtnTextoHover = (C 255 255 255); BtnBorde = (C 200 24 44); BtnBordeAncho = 2
        BtnHover = (C 150 16 36); BtnPress = (C 255 60 80); BarraBtnTexto = (C 236 228 232)
        StatusColor = (C 236 228 232); Fuente = 'Consolas'; FuenteTitulo = 'Consolas'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\velvet\retrato.png'; Carga = 'skins\velvet\carga.png'
        Arma = 'SMG'; Telarana = $true
        # Velvet (su arte de la selección de personaje de Gunsaw); el balanceo y los ojos los mueve Vv-Tick
        Actores = @(
            @{ Id = 'V'; Gif = 'skins\velvet\velvet.png'; Rect = @(544, 50, 214, 266) }
        )
        # dónde tiene los ojos en velvet.png (en proporción de la imagen): los dos grandes y los cuatro pequeños
        Ojos = @(@(0.42, 0.225, 1.0), @(0.555, 0.235, 1.0), @(0.40, 0.165, 0.5), @(0.52, 0.15, 0.5), @(0.46, 0.13, 0.4), @(0.58, 0.18, 0.4))
        # especies de Gunsaw que se acercan a la telaraña (una por cada app)
        Especies = @('Experiment', 'Orange', 'Milky', 'Leapy', 'Chompy', 'Roza', 'Voyager', 'Baron', 'Chik', 'Crystal', 'Icke', 'Shelly', 'Albino')
        Sonidos = @{
            musica = @('skins\velvet\creeps.mp3'); escupe = @('skins\velvet\escupe.wav'); capullo = @('skins\velvet\capullo.wav'); abrazo = @('skins\velvet\abrazo.wav')
            lunge = @('skins\velvet\lunge.wav'); latido = @('skins\velvet\latido.wav'); siseo = @('skins\velvet\siseo.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 22 10 18); BurTexto = (C 240 230 236); BurFuente = 'Consolas'
        IntroLineas = @(
            '- Una extraña criatura femenina parecida a una araña.'
            '- 4 patas enormes le crecen de la espalda. Solo'
            '  sirven para dar miedo.'
            '- Escupe telarañas densas para inmovilizar presas.'
            '- Usa su voz maternal para atraer a los demás...'
            'Si te escupe, aguanta. Cuidado con su resistencia.'
        )
        IntroStats = @('Aim speed: {r}90%{b}   Move speed: {r}93%', 'Reload speed: {r}90%{b}   Health: {g}120')
        IntroPie = @('Tanky, with bad weapon handling', '{g}Hold CTRL/LMB to spit out cobweb')
    }
    # ================================================================ Dune (Gunsaw)
    'Dune' = @{
        Estilo = 'gunsaw'; Titulo = 'Dune'; Sub = '14/14 species unlocked  ·  GUNSAW'; Alto = 312
        Fondo = (C 26 14 30); Borde = (C 10 4 12); Acento = (C 215 190 140)
        TituloColor = (C 224 220 228); SubColor = (C 170 160 180)
        BtnFondo = (C 36 22 40); BtnTexto = (C 226 222 230); BtnTextoHover = (C 255 255 255); BtnBorde = (C 125 112 130); BtnBordeAncho = 1
        BtnHover = (C 110 90 58); BtnPress = (C 60 150 170); BarraBtnTexto = (C 226 222 230)
        StatusColor = (C 226 222 230); Fuente = 'Consolas'; FuenteTitulo = 'Consolas'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\dune\retrato.png'; Arte = 'skins\dune\arte.png'; Arma = 'Rapid-fire revolver'; Hambre = $true; Agua = $true
        Pb = @(410, 62, 190, 150); PbFondo = (C 26 14 30); PbBorde = $false
        Burbuja = @(410, 232, 190, 64); BurFondo = (C 18 9 22); BurTexto = (C 236 226 204); BurFuente = 'Consolas'
        IntroLineas = @(
            '- Una extraña criatura acuática parecida a un insecto.'
            '- Cuerpo flexible, agallas y camuflaje de arena.'
            '- Ojos negros enormes y una boca todavía más grande.'
            '- Mente simple. Solo le mueve el hambre.'
            '- Habla como un cavernícola: "Ggrrgh.. Cueva.. Gris.."'
            'Mucha habilidad, mucho peligro. No lo subestimes.'
        )
        IntroStats = @('Aim speed: {g}135%{b}   Move speed: {g}111%', 'Reload speed: {g}150%{b}   Health: {r}90')
        IntroPie = @('{g}Crouch over corpses to eat them and heal', '{g}Breathes underwater  {r}Lowered health regen')
    }
    # ================================================================ El Cordero y la Cabra (Cult of the Lamb)
    # El Cordero no habla: bala y actúa. La Cabra es su reflejo oscuro: bruta, bromista y gritona.
    'Cordero y Cabra' = @{
        Estilo = 'culto'; Titulo = 'CORDERO & CABRA'; Sub = 'alianza impía  ·  cult of the lamb'; Alto = 312
        Fondo = (C 28 18 22); Borde = (C 150 24 36); Acento = (C 196 34 48)
        TituloColor = (C 238 226 200); SubColor = (C 176 128 214)
        BtnFondo = (C 40 26 30); BtnTexto = (C 238 226 200); BtnTextoHover = (C 255 255 255); BtnBorde = (C 150 24 36); BtnBordeAncho = 2
        BtnHover = (C 120 20 30); BtnPress = (C 120 70 170); BarraBtnTexto = (C 238 226 200)
        StatusColor = (C 238 226 200); Fuente = 'Palatino Linotype'; FuenteTitulo = 'Palatino Linotype'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Gif = 'skins\cordero\cordero.gif'; Mezclar = $true
        FondoImg = 'skins\cordero\templo.jpg'; IntroImg = 'skins\cordero\templo_intro.jpg'
        Actores = @(
            @{ Id = 'L'; Gif = 'skins\cordero\cordero.gif'; Extra = @{ clic = 'skins\cordero\cordero_balido.gif'; baile = 'skins\cordero\cordero_baile.gif' }; Rect = @(428, 64, 152, 176) }
            @{ Id = 'G'; Gif = 'skins\cordero\cabra.gif'; Extra = @{ grito = 'skins\cordero\cabra_grito.gif'; risa = 'skins\cordero\cabra_risa.gif' }; Rect = @(592, 64, 152, 176) }
        )
        Cartel = 'skins\cordero\cartel_cordero.png'; Cartel2 = 'skins\cordero\cartel_cabra.png'
        Sonidos = @{
            balido = @('skins\cordero\balido1.wav', 'skins\cordero\balido2.wav', 'skins\cordero\balido3.wav', 'skins\cordero\balido4.wav')
            voz = @('skins\cordero\voz1.wav', 'skins\cordero\voz2.wav', 'skins\cordero\voz3.wav', 'skins\cordero\voz4.wav'); enfado = @('skins\cordero\enfado.wav')
            grito = @('skins\cordero\grito1.wav', 'skins\cordero\grito2.wav', 'skins\cordero\grito3.wav'); risa = @('skins\cordero\risa.wav')
            ritual = @('skins\cordero\ritual.wav'); campana = @('skins\cordero\campana.wav'); invocar = @('skins\cordero\invocar.wav')
            tentaculos = @('skins\cordero\tentaculos.wav'); comer = @('skins\cordero\munch.wav'); templo = @('skins\cordero\templo.wav')
        }
        Burbuja = @(422, 246, 324, 56); BurFondo = $null; InvFondo = (C 236 222 192); BurTexto = (C 46 24 26); BurFuente = 'Palatino Linotype'
    }
    # ================================================================ Pyrophina y Zaratana (Mewgenics)
    # Dos kaijus que no hablan: rugen. La radio WMEW 99.9 lo narra todo con pánico.
    'Pyrophina y Zaratana' = @{
        Estilo = 'kaiju'; Titulo = 'PYROPHINA VS ZARATANA'; Sub = 'WMEW 99.9  ·  mewgenics'; Alto = 312
        Fondo = (C 22 16 34); Borde = (C 12 8 10); Acento = (C 255 120 30)
        TituloColor = (C 255 214 60); SubColor = (C 255 120 40)
        BtnFondo = (C 26 18 24); BtnTexto = (C 255 236 200); BtnTextoHover = (C 20 12 10); BtnBorde = (C 255 120 30); BtnBordeAncho = 2
        BtnHover = (C 230 90 20); BtnPress = (C 150 150 170); BarraBtnTexto = (C 255 236 200)
        StatusColor = (C 255 214 60); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Gif = 'skins\kaijus\pyro.gif'; Mezclar = $true
        FondoImg = 'skins\kaijus\pmart.jpg'; IntroImg = 'skins\kaijus\calle.jpg'
        Actores = @(
            @{ Id = 'P'; Gif = 'skins\kaijus\pyro.gif'; Extra = @{ ataque = 'skins\kaijus\pyro_ataque.gif'; fuego = 'skins\kaijus\pyro_fuego.gif'; gana = 'skins\kaijus\pyro_gana.gif' }; Rect = @(418, 70, 160, 176) }
            @{ Id = 'Z'; Gif = 'skins\kaijus\zara.gif'; Extra = @{ ataque = 'skins\kaijus\zara_ataque.gif'; meteoros = 'skins\kaijus\zara_meteoros.gif'; gana = 'skins\kaijus\zara_gana.gif' }; Rect = @(580, 96, 172, 150) }
        )
        Cartel = 'skins\kaijus\cartel_pyro.png'; Cartel2 = 'skins\kaijus\cartel_zara.png'
        Sonidos = @{
            pruge = @('skins\kaijus\pyro_ruge1.wav', 'skins\kaijus\pyro_ruge2.wav'); pataque = @('skins\kaijus\pyro_ataque.wav', 'skins\kaijus\pyro_ataque2.wav')
            pfuego = @('skins\kaijus\pyro_fuego.wav'); pgana = @('skins\kaijus\pyro_gana.wav'); pisoton = @('skins\kaijus\pyro_pisoton.wav')
            zruge = @('skins\kaijus\zara_ruge1.wav', 'skins\kaijus\zara_ruge2.wav'); zataque = @('skins\kaijus\zara_ataque.wav', 'skins\kaijus\zara_ataque2.wav')
            zmeteoros = @('skins\kaijus\zara_meteoros.wav'); zmeteoro = @('skins\kaijus\zara_meteoro.wav'); zgana = @('skins\kaijus\zara_gana.wav')
            intro = @('skins\kaijus\intro.wav'); radio = @('skins\kaijus\radio.wav')
        }
        Burbuja = @(424, 256, 322, 50); BurFondo = $null; InvFondo = (C 14 10 14); BurTexto = (C 255 226 120); BurFuente = 'TikaFont Adjusted'
    }
    # ================================================================ Averi (zorrita de Fiddleafox)
    # Bienintencionada pero torpe: lo dice todo con cariño y a veces le sale fatal. Protege a sus amigos y adora los sándwiches de pollo.
    'Averi' = @{
        Estilo = 'zorro'; Titulo = 'Averi'; Sub = 'tu amiga zorrita'; Alto = 312
        Fondo = (C 255 243 226); Borde = (C 196 110 50); Acento = (C 230 128 56)
        TituloColor = (C 255 250 240); SubColor = (C 255 226 180)
        BtnFondo = (C 255 250 240); BtnTexto = (C 110 60 30); BtnTextoHover = (C 110 60 30); BtnBorde = (C 230 128 56); BtnBordeAncho = 2
        BtnHover = (C 255 214 170); BtnPress = (C 150 200 120); BarraBtnTexto = (C 110 60 30)
        StatusColor = (C 110 60 30); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Trebuchet MS'; Opacidad = 1.0; Velocidad = 1
        Ancho = 668; Gif = 'skins\averi\feliz.png'; Mezclar = $true
        Actores = @(
            @{ Id = 'A'; Gif = 'skins\averi\calma.png'; Extra = @{ feliz = 'skins\averi\feliz.png'; antojo = 'skins\averi\antojo.png' }; Rect = @(446, 72, 196, 147); Llenar = $true }
        )
        Sonidos = @{ yip = @('skins\averi\yip1.wav', 'skins\averi\yip2.wav'); comer = @('skins\averi\nam.wav'); corazon = @('skins\averi\corazon.wav'); ups = @('skins\averi\ups.wav') }
        Burbuja = @(424, 254, 228, 50); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 90 50 30); BurFuente = 'Segoe Print'
    }
    # ================================================================ Sebastian Solace (Pressure)
    # El tendero del Hadal Blacksite: simpático de cara al público, sarcástico y teatral, y peligroso si le tocas las narices.
    'Sebastian Solace' = @{
        Estilo = 'pressure'; Titulo = 'SEBASTIAN SOLACE'; Sub = 'hadal blacksite  ·  pressure'; Alto = 312
        Fondo = (C 10 14 20); Borde = (C 70 190 200); Acento = (C 255 190 70)
        TituloColor = (C 220 240 245); SubColor = (C 255 190 70)
        BtnFondo = (C 20 26 32); BtnTexto = (C 220 240 245); BtnTextoHover = (C 10 14 20); BtnBorde = (C 70 190 200); BtnBordeAncho = 1
        BtnHover = (C 70 190 200); BtnPress = (C 255 190 70); BarraBtnTexto = (C 220 240 245)
        StatusColor = (C 220 240 245); Fuente = 'Bahnschrift'; FuenteTitulo = 'Bahnschrift'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\sebastian\dibujo.png'
        FondoImg = 'skins\sebastian\tienda.jpg'; IntroImg = 'skins\sebastian\ventilacion.jpg'
        # dibujo de Sebastian: fanart de MissCupid9 (DeviantArt); detrás del mostrador
        Actores = @(
            @{ Id = 'S'; Gif = 'skins\sebastian\dibujo.png'; Rect = @(452, 42, 290, 256); Respira = $true }
        )
        Sonidos = @{
            flash = @('skins\sebastian\flash.mp3'); compra = @('skins\sebastian\compra.wav')
            conducto = @('skins\sebastian\conducto.wav'); rejilla = @('skins\sebastian\rejilla.wav')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 12 16 22); BurTexto = (C 235 245 248); BurFuente = 'Bahnschrift'
        Tienda = @(
            @{ Id = 'linterna'; Nombre = 'Linterna'; Precio = 5; Img = 'skins\sebastian\obj_linterna.png'; Escaso = $true }
            @{ Id = 'pilas'; Nombre = 'Pilas'; Precio = 2; Img = 'skins\sebastian\obj_pilas.png' }
            @{ Id = 'botiquin'; Nombre = 'Botiquín'; Precio = 6; Img = 'skins\sebastian\obj_botiquin.png' }
            @{ Id = 'breacher'; Nombre = 'Breacher'; Precio = 8; Img = 'skins\sebastian\obj_breacher.png' }
            @{ Id = 'luznegra'; Nombre = 'Luz negra'; Precio = 7; Img = 'skins\sebastian\obj_luznegra.png'; Escaso = $true }
            @{ Id = 'splorg'; Nombre = 'Splorglight'; Precio = 4; Img = 'skins\sebastian\obj_splorg.png' }
            @{ Id = 'flash'; Nombre = 'Flash Beacon'; Precio = 6; Img = $null }
        )
    }
    # ================================================================ Pursuer (Die of Death)
    # Depredador de origen desconocido: rápido, paciente, solo come "carne fresca". Habla poco y siempre con hambre. Toca la armónica.
    'Pursuer' = @{
        Estilo = 'dod'; Titulo = ''; TituloImg = 'skins\pursuer\titulo.png'; Sub = 'die of death  ·  treehouse'; Alto = 312
        Fondo = (C 8 14 10); Borde = (C 0 130 91); Acento = (C 255 52 41)
        TituloColor = (C 60 220 160); SubColor = (C 60 220 160)
        BtnFondo = (C 10 16 12); BtnTexto = (C 200 255 230); BtnTextoHover = (C 10 16 12); BtnBorde = (C 0 130 91); BtnBordeAncho = 2
        BtnHover = (C 0 160 110); BtnPress = (C 255 52 41); BarraBtnTexto = (C 200 255 230)
        StatusColor = (C 60 220 160); Fuente = 'Arial Black'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\pursuer\retrato.png'
        FondoImg = 'skins\pursuer\bosque.jpg'; IntroImg = 'skins\pursuer\intro.gif'
        Actores = @(
            @{ Id = 'P'; Gif = $null; Rect = @(500, 58, 210, 210)
               Tiras = @{ main = @{ Archivo = 'skins\pursuer\giro.png'; Frames = 24; Orden = @(0, 1, 2, 3, 2, 1, 0, 0, 23, 22, 21, 22, 23, 0); Delay = 160 } } }
        )
        Sonidos = @{
            zarpazo = @('skins\pursuer\zarpazo.mp3'); espada = @('skins\pursuer\cleave.wav'); corte = @('skins\pursuer\cleavehit.wav'); envaina = @('skins\pursuer\envaina.mp3')
            aullido = @('skins\pursuer\howlscream.wav'); onda = @('skins\pursuer\howlshockwave.wav', 'skins\pursuer\aullido2.mp3'); acecho = @('skins\pursuer\acecho.mp3')
            aturdido = @('skins\pursuer\stunned.wav'); intro = @('skins\pursuer\intro.mp3')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 6 10 8); BurTexto = (C 70 235 170); BurFuente = 'Arial Black'
    }
    # ================================================================ Kasane Teto (BIRDBRAIN, de Jamie Paige)
    # La quimera de las coletas-taladro: alegre, despistada, con la cabeza llena de pájaros.
    # Nació como broma del 1 de abril, dice que tiene 31 años y le encanta el pan francés.
    'Kasane Teto' = @{
        Estilo = 'teto'; Titulo = 'KASANE TETO'; Sub = 'birdbrain  ·  jamie paige'; Alto = 340
        Fondo = (C 250 218 222); Borde = (C 214 40 64); Acento = (C 246 204 60)
        TituloColor = (C 255 255 255); SubColor = (C 255 232 130)
        BtnFondo = (C 255 248 244); BtnTexto = (C 176 24 48); BtnTextoHover = (C 176 24 48); BtnBorde = (C 214 40 64); BtnBordeAncho = 2
        BtnHover = (C 255 232 140); BtnPress = (C 246 204 60); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 176 24 48); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 730; Mezclar = $true; Gif = 'skins\teto\teto.png'
        Fotos = @('skins\teto\foto1.jpg', 'skins\teto\foto3.jpg', 'skins\teto\foto2.jpg')
        # dibujo de Teto en la pose de BIRDBRAIN: fanart de BugMangaka (DeviantArt); se balancea al ritmo
        Actores = @(
            @{ Id = 'T'; Gif = 'skins\teto\teto.png'; Rect = @(578, 64, 130, 230); Baila = $true }
        )
        # voz: el banco de voz oficial de Teto (UTAU, de Twindrill)
        # voz: frases cortas hechas con el banco de voz inglés oficial de Teto (más agudo y suave, al estilo de Jamie Paige)
        Sonidos = @{
            hi = @('skins\teto\hi.wav'); hiii = @('skins\teto\hiii.wav'); hihi = @('skins\teto\hihi.wav'); hello = @('skins\teto\hello.wav')
            yay = @('skins\teto\yay.wav'); yippee = @('skins\teto\yippee.wav'); wow = @('skins\teto\wow.wav'); teto = @('skins\teto\teto.wav')
            okay = @('skins\teto\okay.wav'); hehe = @('skins\teto\hehe.wav'); huh = @('skins\teto\huh.wav'); uhoh = @('skins\teto\uhoh.wav'); byebye = @('skins\teto\byebye.wav')
            hola = @('skins\teto\hiii.wav', 'skins\teto\hihi.wav', 'skins\teto\hello.wav'); alegre = @('skins\teto\yay.wav', 'skins\teto\yippee.wav', 'skins\teto\wow.wav')
            oops = @('skins\teto\uhoh.wav', 'skins\teto\huh.wav'); pio = @('skins\teto\pio.wav')
            birdbrain = @('skins\teto\birdbrain.wav'); baguette = @('skins\teto\baguette.wav', 'skins\teto\bread.wav'); yes = @('skins\teto\yes.wav'); nonono = @('skins\teto\nonono.wav')
            ow = @('skins\teto\ow.wav'); oops2 = @('skins\teto\oops.wav'); sorry = @('skins\teto\sorry.wav'); morning = @('skins\teto\morning.wav'); goodnight = @('skins\teto\goodnight.wav')
            tweet = @('skins\teto\tweet.wav'); letsgo = @('skins\teto\letsgo.wav'); wheee = @('skins\teto\wheee.wav'); wait = @('skins\teto\wait.wav'); what = @('skins\teto\what.wav')
            cute = @('skins\teto\cute.wav'); hey = @('skins\teto\hey.wav'); seeya = @('skins\teto\seeya.wav', 'skins\teto\byebye.wav'); ohno = @('skins\teto\ohno.wav'); yummy = @('skins\teto\yummy.wav')
            happy = @('skins\teto\happy.wav'); youtube = @('skins\teto\youtube.wav'); word = @('skins\teto\word.wav'); excel = @('skins\teto\excel.wav'); teams = @('skins\teto\teams.wav')
            canta = @('skins\teto\canta1.wav', 'skins\teto\canta2.wav', 'skins\teto\canta3.wav', 'skins\teto\canta4.wav')
        }
        # frases que dice al hacerle clic, cada una con su audio
        Voces = @(
            @('¡Hiii~!', 'hiii'), @('¡Hi hi! ¿Me echabas de menos?', 'hihi'), @('¡Hello! ...es "hola" en inglés. ¡Soy bilingüe!', 'hello')
            @('¡Yay! ¡Un clic! ¡Mi cosa favorita!', 'yay'), @('¡Yippee! *Da una vueltecita.*', 'yippee'), @('¡Wow! ¿Has visto eso? ...yo tampoco.', 'wow')
            @('¡Teto! Así me llamo. Kasane Teto. Apúntalo.', 'teto'), @('¡Okay! ...¿qué me habías pedido?', 'okay'), @('Hehe~ *Se ríe sin saber de qué.*', 'hehe')
            @('¿Huh? ¿Me has llamado?', 'huh'), @('Uh-oh... se me ha olvidado algo. ¿El qué? Ni idea.', 'uhoh'), @('¡Hi! *Saluda con las dos manos.*', 'hi')
            @('¡Birdbrain! ...¿lo he dicho bien? ¡Birdbrain!', 'birdbrain'), @('¡Baguette! *Saca una baguette de no se sabe dónde.*', 'baguette'), @('¡Yes! ...eso es "sí". ¡Sigo siendo bilingüe!', 'yes')
            @('¡No, no, no! ¡Que me despeinas los taladros!', 'nonono'), @('¡Oops! Se me ha caído el pan. ...y el otro pan.', 'oops2'), @('¡Hey! ¿Bailamos? ¡Venga, que nadie mira!', 'hey')
            @('¡Let''s go! ¿A dónde? ¡Ni idea! ¡Vamos!', 'letsgo'), @('¡Cute! ...¿yo? ¡Ay, para!', 'cute'), @('¡Yummy! Huele a pan recién hecho. Ah, no, soy yo.', 'yummy')
            @('¿What? ¿Qué pasa? ¿Hay pájaros?', 'what'), @('¡Wait! ...espera, ¿qué iba a decir?', 'wait'), @('¡Happy! Hoy es un buen día. ¡Todos lo son!', 'happy')
            @('♪ La la la~ ♪ *Canta un trocito y se le olvida el resto.*', 'canta')
        )
        Burbuja = @(424, 298, 294, 34); BurFondo = $null; InvFondo = (C 255 248 244); BurTexto = (C 120 20 40); BurFuente = 'Trebuchet MS'
    }
    # ================================================================ Token (femtanyl)
    'Token' = @{
        Estilo = 'femta'; Titulo = 'TOKEN'; Sub = 'femtanyl  ·  ch4s3r'; Alto = 320
        Fondo = (C 8 4 6); Borde = (C 230 20 40); Acento = (C 255 255 255)
        TituloColor = (C 255 255 255); SubColor = (C 255 60 70)
        BtnFondo = (C 255 255 255); BtnTexto = (C 10 6 8); BtnTextoHover = (C 255 255 255); BtnBorde = (C 10 6 8); BtnBordeAncho = 2
        BtnHover = (C 230 20 40); BtnPress = (C 255 255 255); BarraBtnTexto = (C 10 6 8)
        StatusColor = (C 255 255 255); Fuente = 'Arial Black'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\token\cd1.png'; Logo = 'skins\token\femtanyl_fuego.jpg'; FondoImg = 'skins\token\ciudad.jpg'
        # arte oficial de femtanyl: portadas de su Bandcamp (dibujadas por Noelle Stockwood). Clic en la portada: la siguiente
        Actores = @(
            @{ Id = 'K'; Gif = 'skins\token\cd1.png'; Rect = @(470, 60, 204, 204); Respira = $true
               Extra = @{ cd2 = 'skins\token\cd2.png'; cd3 = 'skins\token\cd3.png'; cd4 = 'skins\token\cd4.png'; cd5 = 'skins\token\cd5.png'; cd6 = 'skins\token\cd6.png'; cd7 = 'skins\token\cd7.png'; cd8 = 'skins\token\cd8.png' } }
        )
        Sonidos = @{
            moneda = @('skins\token\moneda.wav'); golpe = @('skins\token\golpe.wav'); breakcore = @('skins\token\breakcore.wav'); glitch = @('skins\token\glitch.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 10 6 8); BurFuente = 'Consolas'
    }
    # ================================================================ Tetra (YonKaGor)
    'Tetra' = @{
        Estilo = 'pop'; Titulo = 'TETRA'; Sub = "you're just like pop music  ·  yonkagor"; Alto = 320
        Fondo = (C 30 14 52); Borde = (C 255 92 190); Acento = (C 90 230 250)
        TituloColor = (C 255 255 255); SubColor = (C 255 214 120)
        BtnFondo = (C 40 20 70); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 255 255); BtnBorde = (C 90 230 250); BtnBordeAncho = 2
        BtnHover = (C 255 92 190); BtnPress = (C 255 214 120); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 255 255 255); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\tetra\tetra.png'; FondoImg = 'skins\tetra\fondo.jpg'; Logo = 'skins\tetra\failure.png'
        IntroImg = 'skins\tetra\intro.gif'; IntroAudio = 'skins\tetra\intro.mp3'
        # dibujo de Tetra: fanart de Lovavavavania (@Lovavavavania en X), como lámina con marco de neón dentro del acuario
        # (el fondo del dibujo está pintado y no se puede recortar); baila cuando le da por la música.
        # La ficha oficial recortada (tetra.png) se sigue usando cuando sale de invitada.
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\tetra\lamina.png'; Rect = @(580, 62, 158, 228); Respira = $true }
        )
        Sonidos = @{
            ping = @('skins\tetra\ping.wav'); vhs = @('skins\tetra\vhs.wav'); disco = @('skins\tetra\disco.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 40 20 70); BurTexto = (C 255 255 255); BurFuente = 'Trebuchet MS'
    }
    # ================================================================ Kevin (Don't Touch My Pizza, de Nyanwolf)
    # El lobo verde de la animación de Nyanwolf: vive dentro de un dibujo de Paint y nadie toca su pizza.
    'Kevin' = @{
        Estilo = 'pizza'; Titulo = 'KEVIN'; Sub = "don't touch my pizza  ·  nyanwolf"; Alto = 320
        Fondo = (C 255 255 255); Borde = (C 30 30 30); Acento = (C 70 200 40)
        TituloColor = (C 255 255 255); SubColor = (C 255 236 120)
        BtnFondo = (C 255 255 255); BtnTexto = (C 20 20 20); BtnTextoHover = (C 255 255 255); BtnBorde = (C 20 20 20); BtnBordeAncho = 2
        BtnHover = (C 70 200 40); BtnPress = (C 255 110 200); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 20 20 20); Fuente = 'Comic Sans MS'; FuenteTitulo = 'Comic Sans MS'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\kevin\canta.gif'; PbFondo = (C 255 255 255)
        # GIFs de la animación de Nyanwolf (Tenor), recortados por poses
        Actores = @(
            @{ Id = 'V'; Gif = 'skins\kevin\canta.gif'; Rect = @(498, 90, 248, 172)
               Extra = @{ chulo = 'skins\kevin\chulo.gif'; motosierra = 'skins\kevin\motosierra.gif'; mermelada = 'skins\kevin\mermelada.gif'; grita = 'skins\kevin\grita.gif'
                          trabajo = 'skins\kevin\trabajo.gif'; arma = 'skins\kevin\arma.gif'; muerde = 'skins\kevin\muerde.gif'; feliz = 'skins\kevin\feliz.gif'; fuego = 'skins\kevin\fuego.gif'
                          sudor = 'skins\kevin\sudor.gif'; piensa = 'skins\kevin\piensa.gif'; baile = 'skins\kevin\baile.gif'; micro = 'skins\kevin\micro.gif'; unicornio = 'skins\kevin\unicornio.gif' } }
        )
        Sonidos = @{
            polka = @('skins\kevin\polka.mp3'); baile = @('skins\kevin\polka_baile.mp3')
            nam = @('skins\kevin\nam.wav'); grr = @('skins\kevin\grr.wav'); ding = @('skins\kevin\ding.wav'); grito = @('skins\kevin\grito.wav'); pop = @('skins\kevin\pop.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 20 20 20); BurFuente = 'Comic Sans MS'
    }
    # ================================================================ Kennyoung (músico y animador surcoreano de pop-punk)
    # Su personaje de los videoclips, dentro del reproductor de su canal de YouTube.
    'Kennyoung' = @{
        Estilo = 'punk'; Titulo = 'Kennyoung'; Sub = ''; Alto = 320; TituloX = 44
        # estética de sus dibujos: atardecer en el skatepark, borde verde de pegatina y la camisa de cuadros marrón
        Fondo = (C 250 190 150); Borde = (C 70 50 45); Acento = (C 110 235 140)
        TituloColor = (C 255 255 255); SubColor = (C 110 235 140)
        BtnFondo = (C 255 248 240); BtnTexto = (C 70 50 45); BtnTextoHover = (C 30 24 22); BtnBorde = (C 70 50 45); BtnBordeAncho = 2
        BtnHover = (C 110 235 140); BtnPress = (C 255 200 120); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 70 50 45); Fuente = 'Segoe UI'; FuenteTitulo = 'Ink Free'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\kennyoung\habla_cerrada.png'; PbFondo = (C 250 196 160); Avatar = 'skins\kennyoung\avatar.png'
        FondoImg = 'skins\kennyoung\fondo_atardecer.jpg'
        # Kenny (dibujo con la boca cerrada) y las dos bocas abiertas para cuando habla
        Actores = @(
            @{ Id = 'Y'; Gif = 'skins\kennyoung\habla_cerrada.png'; Rect = @(500, 46, 258, 272); Respira = $true
               Extra = @{ abierta1 = 'skins\kennyoung\habla_abierta1.png'; abierta2 = 'skins\kennyoung\habla_abierta2.png' } }
        )
        # mientras se escribe el bocadillo, va cambiando de boca en este orden ('main' es la boca cerrada)
        Habla = @{ Id = 'Y'; Bocas = @('abierta1', 'abierta2', 'abierta1', 'main') }
        Sonidos = @{
            acorde = @('skins\kennyoung\acorde.wav', 'skins\kennyoung\acorde2.wav', 'skins\kennyoung\acorde3.wav'); riff = @('skins\kennyoung\riff.wav')
            kaboom = @('skins\kennyoung\kaboom.wav'); publico = @('skins\kennyoung\publico.wav'); campana = @('skins\kennyoung\campana.wav'); pegar = @('skins\kennyoung\pegar.wav'); flexo = @('skins\kennyoung\flexo.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 246 236); BurTexto = (C 60 42 38); BurFuente = 'Trebuchet MS'
        Canciones = @('Someday', 'Maybe Tomorrow', 'Let''s Go', 'Nothing', 'See You!', 'People Online', 'Loner', 'I Used To', 'Parasocial', 'Ready To Say', 'Good Old Green Days', 'Get Away', 'Lethargy', 'Taste of Summer', 'Trash Talkin''')
    }
    # ================================================================ Enfosi (Roblox, de Tumore)
    # Datos sacados de las wikis del juego (enfosi.miraheze.org y enfosi-tumore.fandom.com)
    'Enfosi' = @{
        Estilo = 'enfosi'; Titulo = 'ENFOSI'; Sub = 'tumore  ·  roblox'; Alto = 320
        Fondo = (C 30 34 48); Borde = (C 40 30 10); Acento = (C 255 214 60)
        TituloColor = (C 40 30 10); SubColor = (C 90 60 10)
        BtnFondo = (C 255 255 255); BtnTexto = (C 25 25 25); BtnTextoHover = (C 25 25 25); BtnBorde = (C 25 25 25); BtnBordeAncho = 2
        BtnHover = (C 255 214 60); BtnPress = (C 255 170 20); BarraBtnTexto = (C 25 25 25)
        StatusColor = (C 255 255 255); Fuente = 'Arial Rounded MT Bold'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\enfosi\giggler_baila.gif'; Logo = 'skins\enfosi\logo.png'; FondoImg = 'skins\enfosi\fondo.jpg'
        # la estatua (un Giggler gigante en un pedestal de oro) y el Glaggle que camina hacia ella
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\enfosi\estatua.png'; Rect = @(402, 96, 128, 172) }
            @{ Id = 'W'; Gif = 'skins\enfosi\giggler.png'; Rect = @(820, 148, 74, 120); Extra = $EnfosiPoses }
        )
        Sonidos = @{
            golpe = @('skins\enfosi\golpe.wav'); buzzer = @('skins\enfosi\buzzer.wav'); revela = @('skins\enfosi\revela.wav'); ojo = @('skins\enfosi\ojo.wav')
            ola = @('skins\enfosi\ola.wav'); confeti = @('skins\enfosi\confeti.wav'); estatua = @('skins\enfosi\estatua.wav'); moneda = @('skins\enfosi\moneda.wav')
            ding = @('skins\enfosi\ding.wav'); alarma = @('skins\enfosi\alarma_jefe.mp3')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 25 25 25); BurFuente = 'Arial Rounded MT Bold'
    }
    # ================================================================ Gran (ivycomb, ANTIHUMAN)
    # Datos de la wiki de ivycomb (wiki.ivy.cm). Imagen y bucles: los vídeos de su personaje en ANTIHUMAN
    'Gran' = @{
        Estilo = 'gran'; Titulo = 'GRAN'; Sub = 'antihuman inc.  ·  ivycomb'; Alto = 320
        Fondo = (C 8 10 9); Borde = (C 32 208 44); Acento = (C 32 208 44)
        TituloColor = (C 32 208 44); SubColor = (C 200 255 205)
        BtnFondo = (C 10 14 11); BtnTexto = (C 200 255 205); BtnTextoHover = (C 8 10 9); BtnBorde = (C 32 208 44); BtnBordeAncho = 2
        BtnHover = (C 32 208 44); BtnPress = (C 255 255 255); BarraBtnTexto = (C 200 255 205)
        StatusColor = (C 200 255 205); Fuente = 'Bahnschrift'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\gran\tapada.gif'; FondoImg = 'skins\gran\remolino.jpg'; IntroImg = 'skins\gran\intro.gif'
        # en el panel se le ve la cara; como invitado (Gif) se le ve tapada
        Actores = @(
            @{ Id = 'G'; Gif = 'skins\gran\gran.gif'; Rect = @(414, 62, 334, 204); Llenar = $true
               Extra = @{ tapar = 'skins\gran\tapar.gif'; tapada = 'skins\gran\tapada.gif' } }
        )
        Sonidos = @{ cancion = @('skins\gran\cancion.mp3') }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 10 14 11); BurTexto = (C 200 255 205); BurFuente = 'Bahnschrift'
    }
    # ================================================================ Evil Scary (Die of Death, Roblox) · ACTUALIZACIÓN DE HALLOWEEN
    # La amenaza de la ronda especial EVIL SCARY: una bola negra con manos que se acerca a saltitos al jugador más cercano.
    # No habla: lo que sale en el bocadillo son los mensajes de la partida (en mayúsculas, como en el juego).
    'Evil Scary' = @{
        Estilo = 'evil'; Titulo = ''; Sub = 'special round  ·  die of death'; Alto = 320; TituloImg = 'skins\evilscary\titulo.png'
        Fondo = (C 10 4 6); Borde = (C 170 20 30); Acento = (C 230 30 40)
        TituloColor = (C 230 30 40); SubColor = (C 200 60 60)
        BtnFondo = (C 18 8 10); BtnTexto = (C 236 220 220); BtnTextoHover = (C 255 255 255); BtnBorde = (C 170 20 30); BtnBordeAncho = 2
        BtnHover = (C 150 14 24); BtnPress = (C 255 255 255); BarraBtnTexto = (C 236 220 220)
        StatusColor = (C 236 220 220); Fuente = 'Arial'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\evilscary\evil.png'; FondoImg = 'skins\evilscary\fondo.jpg'
        Susto = 'skins\evilscary\susto.jpg'; Susto2 = 'skins\evilscary\susto2.jpg'; Render = 'skins\evilscary\render.jpg'
        # la bola negra con las manos que tiemblan (recortada de un GIF del juego); su sitio y su tamaño cambian con la distancia
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\evilscary\evil.png'; Rect = @(520, 120, 140, 53)
               Tiras = @{ main = @{ Archivo = 'skins\evilscary\evil_tira.png'; Frames = 30; Delay = 90 } } }
        )
        Sonidos = @{
            lejos = @('skins\evilscary\rebote_lejos.wav'); medio = @('skins\evilscary\rebote_medio.wav'); cerca = @('skins\evilscary\rebote_cerca.wav')
            stall = @('skins\evilscary\stall.wav'); grito = @('skins\evilscary\grito.wav'); violin = @('skins\evilscary\violin.wav'); susto = @('skins\evilscary\susto.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 18 8 10); BurTexto = (C 236 220 220); BurFuente = 'Arial'
    }
    # ================================================================ Soft Fuzzy Man (Lemon Demon · animación de Aimkid) · ACTUALIZACIÓN DE HALLOWEEN
    # La canción es de Lemon Demon (Neil Cicierega, disco Spirit Phone, 2016) y la animación de Aimkid (2020).
    # En la wiki de Aimkid: es el fantasma de Dipshit (el lobo de "My Trains"), reencarnado en un lobo-fantasma rosa de neón.
    # Personalidad: un hombre-nube que cree que ser un misterio le hace atractivo; ligón, teatral... y en el fondo necesita sentir que existe.
    # Sale con Orange Cat (que usa "elle/they": en sus frases se evita el masculino y el femenino), que se asusta porque no sabe que es él.
    'Soft Fuzzy Man' = @{
        Estilo = 'niebla'; Titulo = 'Soft Fuzzy Man'; Sub = 'lemon demon  ·  aimkid'; Alto = 320
        Fondo = (C 40 16 70); Borde = (C 255 90 230); Acento = (C 255 150 240)
        TituloColor = (C 255 160 245); SubColor = (C 150 240 255)
        BtnFondo = (C 60 24 100); BtnTexto = (C 255 225 250); BtnTextoHover = (C 40 10 60); BtnBorde = (C 255 90 230); BtnBordeAncho = 2
        BtnHover = (C 255 160 245); BtnPress = (C 150 240 255); BarraBtnTexto = (C 255 225 250)
        StatusColor = (C 255 225 250); Fuente = 'Segoe UI'; FuenteTitulo = 'Segoe Print'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\softfuzzy\fuzzy.png'; FondoImg = 'skins\softfuzzy\fondo.jpg'
        IntroCarpeta = 'skins\softfuzzy\intro'; IntroFotos = 220; IntroFps = 18
        # Soft Fuzzy Man (recortado del vídeo): baila de cuerpo entero en el cielo; al hacerle clic, su sonrisa grande;
        # al abrir apps, la carcajada con el anillo de humo (estas dos de busto, desvaneciéndose por abajo como un fantasma).
        # Orange Cat da vueltas por el aire a su lado.
        Actores = @(
            @{ Id = 'F'; Gif = 'skins\softfuzzy\fuzzy.png'; Rect = @(574, 64, 176, 210); Respira = $true
               Tiras = @{ main = @{ Archivo = 'skins\softfuzzy\fuzzy_tira.png'; Frames = 15; Delay = 70; Orden = @(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1) }
                         brazos = @{ Archivo = 'skins\softfuzzy\brazos_tira.png'; Frames = 10; Delay = 65 }
                         cara = @{ Archivo = 'skins\softfuzzy\cara_tira.png'; Frames = 11; Delay = 60 } } }
            @{ Id = 'G'; Gif = 'skins\softfuzzy\gato.png'; Rect = @(436, 120, 130, 92); Respira = $true
               Tiras = @{ main = @{ Archivo = 'skins\softfuzzy\gato_tira.png'; Frames = 12; Delay = 110 } } }
        )
        Sonidos = @{
            intro = @('skins\softfuzzy\intro.mp3'); puff = @('skins\softfuzzy\puff.wav'); viento = @('skins\softfuzzy\viento.wav')
            brillo = @('skins\softfuzzy\brillo.wav'); boing = @('skins\softfuzzy\boing.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 50 20 86); BurTexto = (C 255 230 252); BurFuente = 'Segoe UI'
    }
    # ================================================================ Roaring Knight (Deltarune)
    # El antagonista de Deltarune: una silueta negra con borde blanco que saca Fuentes Oscuras del suelo y crea Mundos Oscuros.
    # Si hay demasiadas Fuentes llega "the Roaring": los Darkners se vuelven piedra y salen Titanes. Jefe del capítulo 3 (Black Knife).
    # No habla: ruge, ríe y corta. En el bocadillo salen los textos de combate de Deltarune ("* ...").
    # Botón FIGHT (debajo de él): minijuego de combate (ver "ROARING KNIGHT: EL MINIJUEGO").
    'Roaring Knight' = @{
        Estilo = 'knight'; Titulo = 'ROARING KNIGHT'; Sub = '* deltarune  ·  black knife'; Alto = 320
        Fondo = (C 0 0 0); Borde = (C 255 255 255); Acento = (C 255 160 64)
        TituloColor = (C 255 255 255); SubColor = (C 190 150 230)
        BtnFondo = (C 0 0 0); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 255 0); BtnBorde = (C 255 255 255); BtnBordeAncho = 2
        BtnHover = (C 0 0 0); BtnPress = (C 255 160 64); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 255 255 255); Fuente = 'Consolas'; FuenteTitulo = 'Consolas'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\knight\quieto.gif'
        # el Knight con su estela de sombras (sprites de combate del juego, pixel art: se dibuja sin suavizar)
        Actores = @(
            @{ Id = 'K'; Gif = 'skins\knight\knight.gif'; Rect = @(548, 62, 200, 172); Pixel = $true
               Extra = @{ roar = 'skins\knight\roar.gif'; apunta = 'skins\knight\apunta.gif'; tajo = 'skins\knight\tajo.gif'; herido = 'skins\knight\herido.gif'; risa = 'skins\knight\risa.gif' } }
        )
        Sonidos = @{
            rugido = @('skins\knight\rugido.wav'); tajo = @('skins\knight\tajo.wav'); aviso = @('skins\knight\aviso.wav'); golpe = @('skins\knight\golpe.wav')
            roce = @('skins\knight\roce.wav'); estrella = @('skins\knight\estrella.wav'); explota = @('skins\knight\explota.wav'); victoria = @('skins\knight\victoria.wav')
            encuentro = @('skins\knight\encuentro.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 0 0 0); BurTexto = (C 255 255 255); BurFuente = 'Consolas'
    }
    # ================================================================ Dybbuk (Mewgenics) · ACTUALIZACIÓN DE HALLOWEEN
    # El jefe del Boneyard (Acto 1, capítulo 3): un gato-fantasma bromista que esquiva con volteretas, da lametazos que chupan
    # el maná, invoca fuegos fatuos y, al "morir", posee a un gato. Al final los muertos del cementerio lo arrastran bajo tierra.
    # Barra de vida como la de Guillotina, con la vida del juego (85). Ficha del personaje en lore\personajes\Dybbuk.md.
    'Dybbuk' = @{
        Estilo = 'boneyard'; Titulo = 'DYBBUK'; Sub = 'boss  ·  the boneyard  ·  mewgenics'; Alto = 320
        Fondo = (C 36 38 44); Borde = (C 16 16 20); Acento = (C 150 172 186)
        TituloColor = (C 232 234 226); SubColor = (C 150 172 186)
        BtnFondo = (C 236 234 224); BtnTexto = (C 22 22 26); BtnTextoHover = (C 22 22 26); BtnBorde = (C 22 22 26); BtnBordeAncho = 2
        BtnHover = (C 226 128 146); BtnPress = (C 150 172 186); BarraBtnTexto = (C 22 22 26)
        StatusColor = (C 232 234 226); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\dybbuk\idle.gif'; FondoImg = 'skins\dybbuk\fondo.jpg'
        Lapida = 'skins\dybbuk\lapida.png'; Wisp = 'skins\dybbuk\wisp.png'; Cartel = 'skins\dybbuk\cartel.png'
        # intro (imágenes del juego): la puerta del cementerio, la colina del jefe, el marco de lápidas, el dibujo de cuando se asoma y su arte de jefe
        IntroPuerta = 'skins\dybbuk\intro_puerta.jpg'; IntroColina = 'skins\dybbuk\intro_colina.jpg'; IntroMarco = 'skins\dybbuk\intro_marco.png'
        IntroAsoma = 'skins\dybbuk\asoma.gif'; IntroJefe = 'skins\dybbuk\intro_jefe.png'
        # las animaciones del juego, todas del mismo tamaño y con los pies en el mismo sitio (el lienzo mide lo mismo que el Rect)
        Actores = @(
            @{ Id = 'D'; Gif = 'skins\dybbuk\idle.gif'; Rect = @(404, 54, 356, 224)
               Extra = @{ herido = 'skins\dybbuk\herido.gif'; lame = 'skins\dybbuk\lame.gif'; muere = 'skins\dybbuk\muere.gif'
                          flip = 'skins\dybbuk\flip.gif'; invoca = 'skins\dybbuk\invoca.gif'; posee = 'skins\dybbuk\posee.gif' } }
        )
        Sonidos = @{
            intro = @('skins\dybbuk\intro.mp3'); lame = @('skins\dybbuk\lame.wav'); flip = @('skins\dybbuk\flip.wav'); wisps = @('skins\dybbuk\wisps.wav')
            posee = @('skins\dybbuk\posee.wav'); suelta = @('skins\dybbuk\suelta.wav'); muere = @('skins\dybbuk\muere.wav'); zombie = @('skins\dybbuk\zombie.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 236 234 224); BurTexto = (C 22 22 26); BurFuente = 'TikaFont Adjusted'
    }
    # ================================================================ Ellie Velázquez (self insert de Ale)
    # Personaje original de Ale ("Ale's version"): humana corrupta de 20 años que viaja por el multiverso. Ficha en lore\personajes\Ellie.md.
    # Solo tiene sus propias frases: NO tiene charlas con las demás skins ni las demás opinan de ella (lo pidió así el creador del panel).
    # Barra GLITCH (su rabia): sube si la pinchas y si hay demasiado silencio; al 100 % entra en MODO GLITCH, se sobrecalienta y se le olvida todo.
    # Las natillas la calman. Se teletransporta y se vuelve invisible de vez en cuando.
    'Ellie' = @{
        Estilo = 'corrupta'; Titulo = 'ELLIE VELÁZQUEZ'; Sub = "self insert  ·  ale's version"; Alto = 320
        Fondo = (C 22 8 20); Borde = (C 255 92 170); Acento = (C 255 92 170)
        TituloColor = (C 255 236 244); SubColor = (C 90 230 255)
        BtnFondo = (C 30 10 28); BtnTexto = (C 255 236 244); BtnTextoHover = (C 255 255 255); BtnBorde = (C 255 92 170); BtnBordeAncho = 2
        BtnHover = (C 200 40 110); BtnPress = (C 90 230 255); BarraBtnTexto = (C 255 236 244)
        StatusColor = (C 255 236 244); Fuente = 'Bahnschrift'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\ellie\cuerpo.png'; FondoImg = 'skins\ellie\fondo.jpg'
        Selfie = 'skins\ellie\selfie.png'; Usuario = 'skins\ellie\user.png'
        # Ellie (su render de cuerpo entero) y un cuenco de natillas que se puede clicar
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\ellie\cuerpo.png'; Rect = @(614, 40, 142, 280); Respira = $true }
            @{ Id = 'N'; Gif = 'skins\ellie\natillas.png'; Rect = @(434, 204, 64, 56) }
        )
        Sonidos = @{
            sirena = @('skins\ellie\sirena.wav'); boom = @('skins\ellie\boom.wav'); glitch = @('skins\ellie\glitch.wav')
            tele = @('skins\ellie\tele.wav'); nam = @('skins\ellie\nam.wav')
        }
        Burbuja = @(424, 272, 184, 40); BurFondo = $null; InvFondo = (C 30 10 28); BurTexto = (C 255 236 244); BurFuente = 'Segoe UI'
    }
    # ================================================================ Nanachi (Made in Abyss)
    # Narehate de la 4ª capa del Abismo: ve el campo de fuerza, cura, dibuja y cocina fatal.
    # Personalidad: pasa de casi todo (seco, sin ganas, "me da igual")... menos de Mitty, su mejor amiga, que está a su lado.
    # Su género no se dice en la obra: en las frases sobre Nanachi se evita el masculino y el femenino.
    'Nanachi' = @{
        Estilo = 'abismo'; Titulo = 'NANACHI'; Sub = 'made in abyss  ·  4ª capa'; Alto = 320
        Fondo = (C 20 36 24); Borde = (C 74 54 40); Acento = (C 236 170 190)
        TituloColor = (C 252 240 214); SubColor = (C 236 170 190)
        BtnFondo = (C 246 236 212); BtnTexto = (C 60 44 34); BtnTextoHover = (C 60 44 34); BtnBorde = (C 92 70 52); BtnBordeAncho = 2
        BtnHover = (C 236 170 190); BtnPress = (C 150 200 150); BarraBtnTexto = (C 252 240 214)
        StatusColor = (C 252 240 214); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Georgia'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\nanachi\chulo.gif'; FondoImg = 'skins\nanachi\escondite.jpg'
        # Nanachi de pie (diseño del anime) y sus caras de los GIF del anime, que salen en su dibujo de la pared
        Actores = @(
            @{ Id = 'N'; Gif = 'skins\nanachi\nanachi.png'; Rect = @(612, 46, 146, 274); Respira = $true }
            # Mitty en su forma de Hueco (modelo del videojuego), a su lado; se le puede acariciar
            @{ Id = 'M'; Gif = 'skins\nanachi\mitty.png'; Rect = @(522, 196, 104, 76); Respira = $true }
        )
        Caritas = @{
            chulo = 'skins\nanachi\chulo.gif'; feliz = 'skins\nanachi\feliz.gif'; nnaa = 'skins\nanachi\nnaa.gif'; mimos = 'skins\nanachi\mimos.gif'
            verguenza = 'skins\nanachi\verguenza.gif'; tapa = 'skins\nanachi\tapa.gif'; risa = 'skins\nanachi\risa.gif'; triste = 'skins\nanachi\triste.gif'
            mastica = 'skins\nanachi\mastica.gif'; sentado = 'skins\nanachi\sentado.gif'; ronroneo = 'skins\nanachi\ronroneo.gif'
        }
        Estofado = 'skins\nanachi\estofado.png'
        Sonidos = @{
            silbato = @('skins\nanachi\silbato.wav'); viento = @('skins\nanachi\viento.wav'); burbujas = @('skins\nanachi\burbujas.wav')
            plof = @('skins\nanachi\plof.wav'); brillo = @('skins\nanachi\brillo.wav'); sorbo = @('skins\nanachi\sorbo.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 246 236 212); BurTexto = (C 60 44 34); BurFuente = 'Trebuchet MS'
        # el estofado del Abismo (receta de verdad del manga) y lo que cae en la olla con cada app
        Ingredientes = @('un pez demonio entero (machacado)', 'un huevo de picomartillo gigante', 'hierba amarilla, bien pegajosa', 'Gintoko desmigado', 'sal. Lo único normal')
    }
    # ================================================================ Malkuth (Library of Ruina)
    # Bibliotecaria Patrona de la Planta de Historia (antes, Sephirah del Equipo de Control de Lobotomy Corp.). Ficha en lore\personajes\Malkuth.md.
    # Alegre, trabajadora y algo torpe; cuando se acuerda de sus fallos se hunde y lo arregla con su ejercicio de respiración.
    # Su música (Malkuth Story y Malkuth Battle 1-3, del juego) suena de fondo y cambia con el NIVEL DE EMOCIÓN.
    'Malkuth' = @{
        Estilo = 'historia'; Titulo = 'MALKUTH'; Sub = 'planta de historia  ·  library of ruina'; Alto = 320
        Fondo = (C 36 26 16); Borde = (C 214 170 90); Acento = (C 236 196 106)
        TituloColor = (C 250 232 180); SubColor = (C 236 196 106)
        BtnFondo = (C 92 60 30); BtnTexto = (C 250 236 200); BtnTextoHover = (C 50 32 14); BtnBorde = (C 214 170 90); BtnBordeAncho = 2
        BtnHover = (C 236 196 106); BtnPress = (C 200 50 45); BarraBtnTexto = (C 250 236 200)
        StatusColor = (C 250 236 200); Fuente = 'Segoe UI'; FuenteTitulo = 'Palatino Linotype'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\malkuth\busto.png'; FondoImg = 'skins\malkuth\fondo.jpg'
        Emblema = 'skins\malkuth\emblema.png'; Ego = 'skins\malkuth\ego.jpg'
        IntroPlanta = 'skins\malkuth\intro_planta.jpg'; IntroAngela = 'skins\malkuth\intro_angela.jpg'
        # sus retratos del juego (las 6 caras de los diálogos) y tres sprites de combate (tropiezo, herida y en guardia)
        Actores = @(
            @{ Id = 'M'; Gif = 'skins\malkuth\malkuth.png'; Rect = @(612, 46, 140, 278); Respira = $true
               Extra = @{ feliz = 'skins\malkuth\feliz.png'; respira = 'skins\malkuth\respira.png'; decidida = 'skins\malkuth\decidida.png'
                          enfado = 'skins\malkuth\enfado.png'; sombria = 'skins\malkuth\sombria.png'
                          tropiezo = 'skins\malkuth\tropiezo.png'; herida = 'skins\malkuth\herida.png'; combate = 'skins\malkuth\combate.png' } }
        )
        Sonidos = @{
            pagina = @('skins\malkuth\pagina.wav'); libro = @('skins\malkuth\libro.wav'); tropiezo = @('skins\malkuth\tropiezo.wav')
            respira = @('skins\malkuth\respira.wav'); emocion = @('skins\malkuth\emocion.wav'); ego = @('skins\malkuth\ego.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 250 242 222); BurTexto = (C 60 40 20); BurFuente = 'Segoe UI'
    }
    'Weathergirl' = @{
        Estilo = 'clima'; Titulo = 'weathergirl'; Sub = 'flavor foley  ·  ft. eleanor forte  ·  el parte del tiempo'; Alto = 320
        Fondo = (C 84 98 146); Borde = (C 230 236 250); Acento = (C 63 91 217)
        TituloColor = (C 255 255 255); SubColor = (C 214 224 250)
        BtnFondo = (C 248 249 253); BtnTexto = (C 30 38 74); BtnTextoHover = (C 255 255 255); BtnBorde = (C 38 48 92); BtnBordeAncho = 1
        BtnHover = (C 63 91 217); BtnPress = (C 30 38 74); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 255 255 255); Fuente = 'Georgia'; FuenteTitulo = 'Georgia'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\weathergirl\eleanor.png'; Portada = 'skins\weathergirl\portada.jpg'
        IntroImg = 'skins\weathergirl\intro.gif'; IntroAudio = 'skins\weathergirl\intro.mp3'
        # Eleanor Forte con la chaqueta de Flavor Foley (arte oficial de su tienda, recortado): la presentadora, de medio cuerpo
        Actores = @(
            @{ Id = 'W'; Gif = 'skins\weathergirl\eleanor.png'; Rect = @(540, 98, 220, 220) }
        )
        Sonidos = @{
            noticia = @('skins\weathergirl\noticia.wav'); trueno = @('skins\weathergirl\trueno.wav'); gota = @('skins\weathergirl\gota.wav')
            paraguas = @('skins\weathergirl\paraguas.wav'); tele = @('skins\weathergirl\tele.wav'); sol = @('skins\weathergirl\sol.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 236 240 250); BurTexto = (C 30 38 74); BurFuente = 'Georgia'
    }
    'Painter' = @{
        Estilo = 'pintor'; Titulo = 'the_p.AI.nter'; Sub = 'z-779  ·  hadal blacksite  ·  pressure'; Alto = 320
        Fondo = (C 192 192 192); Borde = (C 0 0 0); Acento = (C 0 0 128)
        TituloColor = (C 255 255 255); SubColor = (C 200 220 255)
        BtnFondo = (C 192 192 192); BtnTexto = (C 0 0 0); BtnTextoHover = (C 255 255 255); BtnBorde = (C 0 0 0); BtnBordeAncho = 1
        BtnHover = (C 0 0 128); BtnPress = (C 128 128 128); BarraBtnTexto = (C 0 0 0)
        StatusColor = (C 0 0 0); Fuente = 'Tahoma'; FuenteTitulo = 'Tahoma'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\painter\painter_cara.png'
        # Painter es su programa de dibujo (ventana dibujada para la skin): las caras y el paisaje se dibujan por código en el lienzo
        Actores = @(
            @{ Id = 'P'; Gif = 'skins\painter\programa.png'; Rect = @(412, 60, 340, 186) }
        )
        Sonidos = @{
            blip = @('skins\painter\blip.wav'); garabato = @('skins\painter\garabato.wav'); ventilador = @('skins\painter\ventilador.wav')
            error = @('skins\painter\error.wav'); minando = @('skins\painter\minando.wav'); listo = @('skins\painter\listo.wav')
            arranque = @('skins\painter\arranque.wav'); apagar = @('skins\painter\apagar.wav')
        }
        Burbuja = @(424, 250, 322, 64); BurFondo = $null; InvFondo = (C 255 255 225); BurTexto = (C 0 0 0); BurFuente = 'Tahoma'
    }
}

# ================= GRUPOS DEL MENÚ SKINS =================
# El menú Skins enseña las skins agrupadas según de dónde viene cada personaje: una página por grupo
# (con < y > se pasa de un grupo a otro). Cada línea es:  'nombre de la skin' = 'de dónde viene'
# y eso último sale debajo del nombre, como el canal en YouTube.
# El orden de aquí es el orden del menú. Una skin que no esté en ningún grupo sale sola en "Otras".
$GruposSkins = [ordered]@{
    'YouTube' = [ordered]@{
        'SeaDrive'    = 'YonKaGor'
        'Tetra'       = 'YonKaGor'
        'Kennyoung'   = 'Kennyoung'
        'Token'       = 'femtanyl'
        'Static Miku' = 'Flavor Foley'
        'Weathergirl' = 'Flavor Foley'
        'Kasane Teto' = 'Jamie Paige'
        'Kevin'       = 'Nyanwolf'
        'Gran'        = 'ivycomb'
    }
    'Roblox' = [ordered]@{
        'c00lgui'          = 'c00lkidd'
        'Mikaela'          = 'PURSUITCORE'
        'Sebastian Solace' = 'Pressure'
        'Painter'          = 'Pressure'
        'Pursuer'          = 'Die of Death'
        'Enfosi'           = 'Tumore'
    }
    'Videojuegos' = [ordered]@{
        'Guillotina'           = 'Mewgenics'
        'Zodiac'               = 'Mewgenics'
        'Pyrophina y Zaratana' = 'Mewgenics'
        'Velvet'               = 'Gunsaw'
        'Dune'                 = 'Gunsaw'
        'Angela'               = 'Lobotomy Corp.'
        'Malkuth'              = 'Library of Ruina'
        'Cordero y Cabra'      = 'Cult of the Lamb'
        'Roaring Knight'       = 'Deltarune'
    }
    'Halloween' = [ordered]@{
        'Evil Scary' = 'Die of Death'
        'Soft Fuzzy Man' = 'Lemon Demon · Aimkid'
        'Dybbuk' = 'Mewgenics'
    }
    'Anime' = [ordered]@{
        'Nanachi' = 'Made in Abyss'
    }
    'Artistas' = [ordered]@{
        'Averi' = 'Fiddleafox'
    }
    'Amigos' = [ordered]@{
        'Ellie' = "Self insert de Ale"
    }
}
$SkinsPorPagina = 9   # 3 columnas x 3 filas; un grupo con más skins ocupa varias páginas

# ================= SKINS ARCHIVADAS =================
# Una skin archivada no sale en el menú Skins ni en las charlas con invitados (ni como invitada).
# Solo se puede poner desde Ajustes > "Skins archivadas", y conserva sus frases propias y sus opiniones.
# La lista está en archivadas.txt (un nombre por línea) y se cambia desde esa misma ventana.
$ArchivoArchivadas = Join-Path $Raiz 'archivadas.txt'
function Cargar-Archivadas {
    $script:archivadas = @()
    if (-not (Test-Path -LiteralPath $ArchivoArchivadas)) { return }
    foreach ($l in [IO.File]::ReadAllLines($ArchivoArchivadas, [Text.Encoding]::UTF8)) {
        $n = $l.Trim(); if ($n -and -not $n.StartsWith('#') -and $Skins.Contains($n)) { $script:archivadas += $n }
    }
}
function Guardar-Archivadas {
    $l = @('# Skins archivadas: no salen en el menú Skins ni en las charlas. Se ponen desde Ajustes > Skins archivadas.', '# Un nombre por línea (el nombre exacto de la skin).') + @($script:archivadas)
    try { [IO.File]::WriteAllLines($ArchivoArchivadas, [string[]]$l, (New-Object Text.UTF8Encoding $false)) } catch {}
}
function Es-Archivada($n) { return ($script:archivadas -contains $n) }
Cargar-Archivadas

# lista de páginas del menú Skins: cada una con su grupo y sus skins (@{ Nombre; Origen })
function Paginas-Skins {
    $grupos = [ordered]@{}; $puestas = @{}
    foreach ($n in $script:archivadas) { $puestas[$n] = $true }   # las archivadas no salen en el menú
    foreach ($gr in $GruposSkins.Keys) {
        $lista = New-Object System.Collections.ArrayList
        foreach ($n in $GruposSkins[$gr].Keys) {
            if ($Skins.Contains($n) -and -not $puestas.ContainsKey($n)) { [void]$lista.Add(@{ Nombre = $n; Origen = $GruposSkins[$gr][$n] }); $puestas[$n] = $true }
        }
        if ($lista.Count -gt 0) { $grupos[$gr] = $lista }
    }
    $resto = New-Object System.Collections.ArrayList
    foreach ($n in $Skins.Keys) { if (-not $puestas.ContainsKey($n)) { [void]$resto.Add(@{ Nombre = $n; Origen = '' }) } }
    if ($resto.Count -gt 0) { $grupos['Otras'] = $resto }
    $paginas = New-Object System.Collections.ArrayList
    foreach ($gr in $grupos.Keys) {
        $lista = $grupos[$gr]; $partes = [int][Math]::Ceiling($lista.Count / $SkinsPorPagina)
        for ($p = 0; $p -lt $partes; $p++) {
            $items = New-Object System.Collections.ArrayList
            for ($i = $p * $SkinsPorPagina; $i -lt [Math]::Min($lista.Count, ($p + 1) * $SkinsPorPagina); $i++) { [void]$items.Add($lista[$i]) }
            [void]$paginas.Add(@{ Grupo = $gr; Parte = $p + 1; Partes = $partes; Items = $items })
        }
    }
    return ,$paginas
}
# en qué página del menú está una skin (para abrir el menú justo en su grupo)
function Pagina-De-Skin($nombre) {
    $ps = Paginas-Skins
    for ($i = 0; $i -lt $ps.Count; $i++) { foreach ($it in $ps[$i].Items) { if ($it.Nombre -eq $nombre) { return $i } } }
    return 0
}

# la primera vez que se abre (sin skin.txt) sale SeaDrive: es la skin con menos luces y movimiento
$script:skinNombre = 'SeaDrive'
if (Test-Path $ArchivoSkin) { $s = (Get-Content $ArchivoSkin -Raw).Trim(); if ($Skins.Contains($s)) { $script:skinNombre = $s } }

$PorPagina = 12
$script:pagina = 0
$script:modoSkins = $false
$script:pagSkins = 0   # página del menú Skins que se está viendo
$script:glitching = $false
$script:transicion = $false
$script:pb = $null
$script:imgs = @{}
$script:caras = @{}
$script:caraModo = 'cerrados'
$script:tvRuido = $null
$script:urlLbl = $null
$script:bi = 0
$script:energia = 0
function Contar-Paginas { $script:totalPaginas = [int][Math]::Max(1, [Math]::Ceiling(@($script:Botones).Count / $PorPagina)) }
Contar-Paginas

function Azar($lista) { if ($lista -and @($lista).Count -gt 0) { $l = @($lista); return $l[$Rnd.Next($l.Count)] } else { return '' } }
function Ocupado { return ($script:glitching -or $script:transicion) }
function Ruta($rel) { return (Join-Path $Raiz $rel) }

function Doble-Buffer($ctl) {
    [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance').SetValue($ctl, $true, $null)
}

try { Add-Type -AssemblyName PresentationCore } catch {}
$script:reproductores = New-Object System.Collections.ArrayList
function Sonido($clave) { Sonido-De $script:skinNombre $clave }
$script:ultimoSonido = 0
function Sonido-De($nombre, $clave) {
    $k = $Skins[$nombre]
    if (-not $k -or -not $k.Sonidos -or -not $k.Sonidos[$clave]) { return }
    if (-not $script:aj.Sonido) { return }
    $script:ultimoSonido = [Environment]::TickCount
    try {
        $ruta = Ruta (Azar $k.Sonidos[$clave])
        if ($ruta -like '*.mp3' -or $k.Mezclar -or $script:aj.Volumen -lt 100) {
            # los mp3 (y las skins que mezclan sonidos) se reproducen con el reproductor de Windows: pueden sonar a la vez
            $mp = New-Object System.Windows.Media.MediaPlayer
            $mp.Open([Uri]$ruta); $mp.Volume = [Math]::Max(0.0, [Math]::Min(1.0, $script:aj.Volumen / 100.0)); $mp.Play()
            [void]$script:reproductores.Add($mp)
            if ($script:reproductores.Count -gt 12) { $script:reproductores[0].Close(); $script:reproductores.RemoveAt(0) }
        } else {
            $p = New-Object System.Media.SoundPlayer($ruta); $p.Play()
        }
    } catch {}
}

# hitmarker estilo shooter (X blanca con borde negro)
function Dibujar-Hit($g, $x, $y, $s) {
    $negro = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 5); $blanco = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2.5)
    foreach ($pen in @($negro, $blanco)) {
        $g.DrawLine($pen, ($x - $s), ($y - $s), ($x - $s * 0.35), ($y - $s * 0.35)); $g.DrawLine($pen, ($x + $s), ($y - $s), ($x + $s * 0.35), ($y - $s * 0.35))
        $g.DrawLine($pen, ($x - $s), ($y + $s), ($x - $s * 0.35), ($y + $s * 0.35)); $g.DrawLine($pen, ($x + $s), ($y + $s), ($x + $s * 0.35), ($y + $s * 0.35))
    }
    $negro.Dispose(); $blanco.Dispose()
}

# texto grueso con borde negro (para los carteles)
function Texto-Borde($g, $txt, $fuente, $tam, $x, $y, $color) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, $tam, (New-Object System.Drawing.PointF($x, $y)), [System.Drawing.StringFormat]::GenericDefault)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 8); $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $path); $g.FillPath((New-Object System.Drawing.SolidBrush($color)), $path)
    $pen.Dispose(); $path.Dispose()
}

# ruido de tele (estática) rápido: bytes aleatorios en una imagen en escala de grises
function Nuevo-Ruido($w, $h) {
    $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format8bppIndexed)
    $pal = $b.Palette
    for ($i = 0; $i -lt 256; $i++) { $pal.Entries[$i] = [System.Drawing.Color]::FromArgb($i, $i, $i) }
    $b.Palette = $pal
    Llenar-Ruido $b
    return $b
}
function Llenar-Ruido($b) {
    $r = New-Object System.Drawing.Rectangle(0, 0, $b.Width, $b.Height)
    $d = $b.LockBits($r, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $b.PixelFormat)
    $n = $d.Stride * $b.Height
    $bytes = New-Object byte[] $n
    $Rnd.NextBytes($bytes)
    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $d.Scan0, $n)
    $b.UnlockBits($d)
}

# fondos pre-dibujados (se dibujan una vez y se reutilizan)
function Fondo-Hexagonos($W, $H, $color) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $pen = New-Object System.Drawing.Pen($color, 1)
    $r = 13; $hw = [Math]::Sqrt(3) * $r; $j = 0
    for ($y = 0.0; $y -lt $H + $r; $y += 1.5 * $r) {
        $off = if ($j % 2) { $hw / 2 } else { 0 }
        for ($x = $off; $x -lt $W + $hw; $x += $hw) {
            $pts = New-Object 'System.Drawing.PointF[]' 6
            for ($q = 0; $q -lt 6; $q++) { $a = [Math]::PI / 180 * (60 * $q - 30); $pts[$q] = New-Object System.Drawing.PointF(($x + $r * [Math]::Cos($a)), ($y + $r * [Math]::Sin($a))) }
            $g.DrawPolygon($pen, $pts)
        }
        $j++
    }
    $pen.Dispose(); $g.Dispose()
    return $bmp
}
function Fondo-Papel($W, $H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $g.Clear((C 232 220 190))
    $r2 = New-Object System.Random(7)
    $b1 = New-Object System.Drawing.SolidBrush((C 214 198 162)); $b2 = New-Object System.Drawing.SolidBrush((C 222 208 175))
    for ($i = 0; $i -lt 260; $i++) { $s = $r2.Next(2, 9); $g.FillEllipse((@($b1, $b2)[$r2.Next(2)]), $r2.Next($W), $r2.Next($H), $s, $s) }
    $b1.Dispose(); $b2.Dispose(); $g.Dispose()
    return $bmp
}
function Fondo-Casa($W, $H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    # papel pintado a rayas con rombos
    for ($x = 0; $x -lt $W; $x += 24) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 62 44 52))), $x, 0, 12, $H)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 52 36 44))), ($x + 12), 0, 12, $H)
    }
    $orn = New-Object System.Drawing.SolidBrush((C 78 56 64))
    for ($y = 70; $y -lt 270; $y += 30) { for ($x = 6; $x -lt $W; $x += 24) {
        $o = if ((($y - 70) / 30) % 2) { 12 } else { 0 }
        $g.FillPolygon($orn, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(($x + $o), ($y - 5))), (New-Object System.Drawing.PointF(($x + $o + 4), $y)), (New-Object System.Drawing.PointF(($x + $o), ($y + 5))), (New-Object System.Drawing.PointF(($x + $o - 4), $y))))
    } }
    $orn.Dispose()
    # zócalo y suelo de madera
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 34 24 26))), 0, 262, $W, 6)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 92 60 40))), 0, 268, $W, ($H - 268))
    $junta = New-Object System.Drawing.Pen((C 62 40 26), 1)
    foreach ($y in @(282, 298, 314, 330)) { $g.DrawLine($junta, 0, $y, $W, $y) }
    $r2 = New-Object System.Random(3)
    foreach ($y in @(268, 282, 298, 314, 330)) { for ($x = $r2.Next(0, 80); $x -lt $W; $x += $r2.Next(70, 140)) { $g.DrawLine($junta, $x, $y, $x, ($y + 15)) } }
    $junta.Dispose(); $g.Dispose()
    return $bmp
}
function Fondo-Desierto($W, $H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    # cielo con tres tonos de atardecer
    $cielo = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 56, $W, 212)), (C 0 0 0), (C 0 0 0), 90)
    $mezcla = New-Object System.Drawing.Drawing2D.ColorBlend(3)
    $mezcla.Colors = @((C 196 78 64), (C 242 140 66), (C 252 212 146)); $mezcla.Positions = @([float]0, [float]0.5, [float]1)
    $cielo.InterpolationColors = $mezcla
    $g.FillRectangle($cielo, 0, 56, $W, 212); $cielo.Dispose()
    # sol con halo
    foreach ($q in @(@(70, 40), @(50, 60), @(36, 90))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($q[1], 255, 224, 150))), (525 - $q[0]), (196 - $q[0]), (2 * $q[0]), (2 * $q[0])) }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 236 160))), 497, 168, 56, 56)
    # montañas lejanas y mesetas
    $lej = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 240)), (New-Object System.Drawing.PointF(60, 214)), (New-Object System.Drawing.PointF(110, 228)), (New-Object System.Drawing.PointF(190, 200)), (New-Object System.Drawing.PointF(260, 226)), (New-Object System.Drawing.PointF(340, 206)), (New-Object System.Drawing.PointF(420, 230)), (New-Object System.Drawing.PointF(500, 210)), (New-Object System.Drawing.PointF(616, 232)), (New-Object System.Drawing.PointF(616, 270)), (New-Object System.Drawing.PointF(0, 270)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 200 112 84))), $lej)
    $mes = New-Object System.Drawing.SolidBrush((C 160 76 48))
    $g.FillPolygon($mes, [System.Drawing.Point[]]@((New-Object System.Drawing.Point(0, 268)), (New-Object System.Drawing.Point(24, 238)), (New-Object System.Drawing.Point(140, 238)), (New-Object System.Drawing.Point(168, 268))))
    $g.FillPolygon($mes, [System.Drawing.Point[]]@((New-Object System.Drawing.Point(390, 268)), (New-Object System.Drawing.Point(428, 230)), (New-Object System.Drawing.Point(548, 230)), (New-Object System.Drawing.Point(600, 268))))
    $mes.Dispose()
    # arena con granitos
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 232 192 126))), 0, 266, $W, ($H - 266))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 170 104))), 0, 266, $W, 3)
    $r2 = New-Object System.Random(11); $gr = New-Object System.Drawing.SolidBrush((C 206 160 96))
    for ($i = 0; $i -lt 160; $i++) { $g.FillEllipse($gr, $r2.Next($W), $r2.Next(270, $H), 2, 2) }
    $gr.Dispose()
    # saguaros
    $cac = New-Object System.Drawing.SolidBrush((C 66 108 56)); $bor = New-Object System.Drawing.Pen((C 40 70 34), 1.5)
    foreach ($cx in @(48, 318)) {
        foreach ($pz in @(@($cx, 270, 10, 34, 5), @(($cx - 10), 280, 8, 14, 4), @(($cx - 10), 290, 14, 6, 3), @(($cx + 12), 276, 8, 12, 4), @(($cx + 6), 286, 14, 6, 3))) {
            $p = Ruta-Redonda $pz[0] $pz[1] $pz[2] $pz[3] $pz[4]; $g.FillPath($cac, $p); $g.DrawPath($bor, $p); $p.Dispose()
        }
    }
    $cac.Dispose(); $bor.Dispose(); $g.Dispose()
    return $bmp
}
# dibuja una imagen cubriendo un recuadro (recorta lo que sobra); $ancla = qué parte se conserva (0..1)
function Imagen-Cubrir($g, $ruta, $x, $y, $w, $h, $ax, $ay) {
    $propia = $ruta -is [string]
    $img = if ($propia) { Cargar-Img $ruta } else { $ruta }
    if (-not $img) { return }
    $s = [Math]::Max($w / $img.Width, $h / $img.Height); $sw = $w / $s; $sh = $h / $s
    $src = New-Object System.Drawing.RectangleF([float](($img.Width - $sw) * $ax), [float](($img.Height - $sh) * $ay), [float]$sw, [float]$sh)
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)), $src, [System.Drawing.GraphicsUnit]::Pixel)
    if ($propia) { $img.Dispose() }
}
function Degradado($g, $x, $y, $w, $h, $c1, $c2, $ang) {
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)), $c1, $c2, [float]$ang)
    $g.FillRectangle($br, [float]$x, [float]$y, [float]$w, [float]$h); $br.Dispose()
}
function ARGB($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
# ---- Zodiac: atardecer del oeste dibujado (cielo, sol con franjas, mesetas, suelo y carretera) ----
function Pintar-Atardecer($g, $x, $y, $w, $h, $hor, $sx, $sr) {
    $st = $g.Save()
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)))
    $cielo = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]($y - 1), [float]$w, [float]($hor - $y + 2))), [System.Drawing.Color]::Black, [System.Drawing.Color]::Black, [float]90)
    $cb = New-Object System.Drawing.Drawing2D.ColorBlend(4)
    $cb.Colors = [System.Drawing.Color[]]@((C 44 20 68), (C 138 38 80), (C 234 96 58), (C 255 198 100)); $cb.Positions = [float[]]@(0, 0.4, 0.78, 1)
    $cielo.InterpolationColors = $cb
    $g.FillRectangle($cielo, [float]$x, [float]$y, [float]$w, [float]($hor - $y))
    # estrellitas que se apagan con el atardecer
    $r = New-Object System.Random 7
    for ($i = 0; $i -lt 22; $i++) { $ex = $x + $r.Next(0, [int]$w); $ey = $y + $r.Next(0, [int](($hor - $y) * 0.35)); $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB (60 + $r.Next(0, 120)) 255 236 220))), [float]$ex, [float]$ey, 1.8, 1.8) }
    # rayos de sol
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]($hor - $y))))
    $rb = New-Object System.Drawing.SolidBrush((ARGB 30 255 230 170))
    for ($i = 0; $i -lt 18; $i++) {
        $a1 = [Math]::PI / 180 * ($i * 20 - 5); $a2 = [Math]::PI / 180 * ($i * 20 + 5)
        $g.FillPolygon($rb, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$sx, [float]$hor)), (New-Object System.Drawing.PointF([float]($sx + 900 * [Math]::Cos($a1)), [float]($hor + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($sx + 900 * [Math]::Cos($a2)), [float]($hor + 900 * [Math]::Sin($a2))))))
    }
    $rb.Dispose()
    # resplandor y sol con franjas
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($sx - $sr * 3), [float]($hor - $sr * 3), [float]($sr * 6), [float]($sr * 6))
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pg.CenterColor = (ARGB 160 255 226 140); $pg.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 255 160 80))
    $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose()
    $sol = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]($sx - $sr), [float]($hor - $sr * 1.25), [float]($sr * 2), [float]($sr * 2))), (C 255 246 176), (C 255 128 70), [float]90)
    $g.FillEllipse($sol, [float]($sx - $sr), [float]($hor - $sr * 1.25), [float]($sr * 2), [float]($sr * 2)); $sol.Dispose()
    for ($k = 0; $k -lt 4; $k++) { $by = $hor - $sr * 0.12 - $k * $sr * 0.2; $g.FillRectangle($cielo, [float]($sx - $sr - 2), [float]$by, [float]($sr * 2 + 4), [float](1.5 + (3 - $k) * 1.6)) }
    $cielo.Dispose()
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)))
    # mesetas lejanas y cercanas
    $f = { param($fx, $fy) New-Object System.Drawing.PointF([float]($x + $w * $fx), [float]($hor - $fy)) }
    $lejos = [System.Drawing.PointF[]]@((& $f 0 0), (& $f 0 18), (& $f 0.06 18), (& $f 0.08 34), (& $f 0.22 34), (& $f 0.25 16), (& $f 0.4 16), (& $f 0.44 8), (& $f 0.62 8), (& $f 0.66 28), (& $f 0.7 40), (& $f 0.84 40), (& $f 0.87 22), (& $f 1 22), (& $f 1 0))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 168 62 86))), $lejos)
    $cerca = [System.Drawing.PointF[]]@((& $f 0 0), (& $f 0 30), (& $f 0.03 30), (& $f 0.05 52), (& $f 0.13 52), (& $f 0.16 30), (& $f 0.2 10), (& $f 0.78 6), (& $f 0.86 14), (& $f 0.9 46), (& $f 0.97 46), (& $f 0.99 24), (& $f 1 24), (& $f 1 0))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 104 34 62))), $cerca)
    # suelo del desierto
    $suelo = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]($hor - 1), [float]$w, [float]($y + $h - $hor + 2))), (C 214 110 62), (C 116 46 40), [float]90)
    $g.FillRectangle($suelo, [float]$x, [float]$hor, [float]$w, [float]($y + $h - $hor)); $suelo.Dispose()
    $g.DrawLine((New-Object System.Drawing.Pen((ARGB 150 255 214 150), 1.5)), [float]$x, [float]$hor, [float]($x + $w), [float]$hor)
    for ($i = 0; $i -lt 9; $i++) { $ey = $hor + 6 + $i * $i * 1.6; $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 34 80 20 20))), [float]($x + $r.Next(-40, [int]$w)), [float]$ey, [float](60 + $i * 14), [float](2 + $i * 0.5)) }
    # carretera que se pierde hacia el sol
    $abajo = $y + $h
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 90 70 24 30))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($sx - 4), [float]$hor)), (New-Object System.Drawing.PointF([float]($sx + 4), [float]$hor)), (New-Object System.Drawing.PointF([float]($sx + $w * 0.5), [float]$abajo)), (New-Object System.Drawing.PointF([float]($sx - $w * 0.5), [float]$abajo))))
    $raya = New-Object System.Drawing.SolidBrush((ARGB 150 255 214 120))
    foreach ($t in @(0.08, 0.2, 0.36, 0.58, 0.88)) { $t2 = $t + 0.06 + $t * 0.08; $ya = $hor + ($abajo - $hor) * $t; $yb = $hor + ($abajo - $hor) * [Math]::Min(1, $t2); $wa = 0.6 + $t * 3; $wb = 0.6 + $t2 * 3
        $g.FillPolygon($raya, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($sx - $wa), [float]$ya)), (New-Object System.Drawing.PointF([float]($sx + $wa), [float]$ya)), (New-Object System.Drawing.PointF([float]($sx + $wb), [float]$yb)), (New-Object System.Drawing.PointF([float]($sx - $wb), [float]$yb)))) }
    $raya.Dispose()
    $g.Restore($st)
}
# saguaro a contraluz (tronco y dos brazos redondeados)
function Cactus-Silueta($g, $x, $base, $alto, $col) {
    $br = New-Object System.Drawing.SolidBrush($col); $t = $alto * 0.17
    foreach ($pz in @(@(($x - $t / 2), ($base - $alto), $t, $alto), @(($x - $t * 2.1), ($base - $alto * 0.62), ($t * 0.8), ($alto * 0.34)), @(($x - $t * 2.1), ($base - $alto * 0.36), ($t * 1.8), ($t * 0.7)), @(($x + $t * 1.3), ($base - $alto * 0.8), ($t * 0.8), ($alto * 0.4)), @(($x + $t * 0.2), ($base - $alto * 0.48), ($t * 1.8), ($t * 0.7)))) {
        $p = Ruta-Redonda $pz[0] $pz[1] $pz[2] $pz[3] ($t * 0.4); $g.FillPath($br, $p); $p.Dispose()
    }
    $br.Dispose()
}
# planta rodadora: una maraña de ramitas que gira
function Dibujar-Rodadora($g, $x, $y, $rad, $ang) {
    $st = $g.Save(); $g.TranslateTransform([float]$x, [float]$y); $g.RotateTransform([float]$ang)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 70 120 70 30))), [float](-$rad), [float](-$rad), [float](2 * $rad), [float](2 * $rad))
    $r = New-Object System.Random 3
    foreach ($c in @((C 120 74 34), (C 168 116 58), (C 92 54 24))) {
        $pen = New-Object System.Drawing.Pen($c, 1.6)
        for ($i = 0; $i -lt 7; $i++) { $a = $r.Next(0, 360); $rr = $rad * (0.45 + $r.NextDouble() * 0.55); $g.DrawArc($pen, [float](-$rr + $r.Next(-3, 4)), [float](-$rr + $r.Next(-3, 4)), [float](2 * $rr), [float](2 * $rr * (0.7 + $r.NextDouble() * 0.3)), [float]$a, [float](110 + $r.Next(0, 120))) }
        $pen.Dispose()
    }
    $g.Restore($st)
}
# buitre que planea en círculos (una V que aletea despacio)
function Dibujar-Buitre($g, $x, $y, $esc, $fase) {
    $al = [Math]::Sin($fase) * 3 * $esc
    $pen = New-Object System.Drawing.Pen((ARGB 220 34 12 26), [float](2.2 * $esc)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $g.DrawBezier($pen, [float]($x - 11 * $esc), [float]($y - 2 * $esc + $al), [float]($x - 6 * $esc), [float]($y - 6 * $esc + $al), [float]($x - 3 * $esc), [float]($y - 1 * $esc), [float]$x, [float]($y + 1 * $esc))
    $g.DrawBezier($pen, [float]($x + 11 * $esc), [float]($y - 2 * $esc + $al), [float]($x + 6 * $esc), [float]($y - 6 * $esc + $al), [float]($x + 3 * $esc), [float]($y - 1 * $esc), [float]$x, [float]($y + 1 * $esc))
    $pen.Dispose()
}
# texto con borde de color (no solo negro)
function Texto-Color($g, $txt, $fuente, $tam, $x, $y, $relleno, $borde, $grosor) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, [float]$tam, (New-Object System.Drawing.PointF([float]$x, [float]$y)), [System.Drawing.StringFormat]::GenericDefault)
    $pen = New-Object System.Drawing.Pen($borde, [float]$grosor); $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $path); $g.FillPath((New-Object System.Drawing.SolidBrush($relleno)), $path)
    $pen.Dispose(); $path.Dispose()
}
# fondo de las skins nuevas, dibujado una sola vez a la resolución real de la pantalla
function Fondo-Escena($k, $W, $H) {
    $Z = $script:K
    $bmp = New-Object System.Drawing.Bitmap([int][Math]::Ceiling($W * $Z), [int][Math]::Ceiling($H * $Z))
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $g.ScaleTransform($Z, $Z)
    switch ($k.Estilo) {
        'culto' {
            # el Templo del Cordero del juego
            $g.Clear((C 20 8 10))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.62
            # velo oscuro a la izquierda para los botones
            Degradado $g 0 0 420 $H (ARGB 225 18 6 9) (ARGB 150 18 6 9) 0
            Degradado $g 420 0 70 $H (ARGB 150 18 6 9) (ARGB 0 18 6 9) 0
            # sombra abajo para el pergamino y luz roja bajo los pies
            Degradado $g 400 200 ($W - 400) ($H - 200) (ARGB 0 10 2 4) (ARGB 190 10 2 4) 90
            foreach ($cx in @(504, 668)) {
                $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse([float]($cx - 70), 222, 140, 34)
                $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p); $pg.CenterColor = (ARGB 150 220 30 40); $pg.SurroundColors = @((ARGB 0 220 30 40))
                $g.FillPath($pg, $p); $pg.Dispose(); $p.Dispose()
            }
            # barra del título
            Degradado $g 0 0 $W 56 (ARGB 240 10 4 6) (ARGB 200 10 4 6) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 34 48))), 0, 53, [int]($W / 2), 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 130 70 190))), [int]($W / 2), 53, ($W - [int]($W / 2)), 3)
            # ojo de la corona junto al título
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 60 8 14))), ($W - 262), 14, 34, 22)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 220 30 40))), ($W - 253), 17, 16, 16)
            $g.FillEllipse([System.Drawing.Brushes]::Black, ($W - 248), 18, 6, 14)
        }
        'kaiju' {
            # el P Mart de la cinemática de las kaijus (donde se queda atrapada Tracy)
            $g.Clear((C 30 26 30))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.35 0.75
            # atardecer: tono cálido sobre la escena
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 120 40 20))), 0, 0, $W, $H)
            Degradado $g 0 0 420 $H (ARGB 228 14 10 16) (ARGB 160 14 10 16) 0
            Degradado $g 420 0 70 $H (ARGB 160 14 10 16) (ARGB 0 14 10 16) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 8 6 10) (ARGB 200 8 6 10) 90
            # sombras de las dos en el aparcamiento
            foreach ($q in @(@(498, 70), @(666, 90))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), [float]($q[0] - $q[1]), 236, [float](2 * $q[1]), 20) }
            # barra superior negra con franjas de peligro
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 240 12 8 10))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 200 40))), 0, 52, $W, 6)
            $neg = New-Object System.Drawing.SolidBrush((C 12 8 10))
            for ($x = -10; $x -lt $W; $x += 16) { $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF($x, 52)), (New-Object System.Drawing.PointF(($x + 8), 52)), (New-Object System.Drawing.PointF(($x + 2), 58)), (New-Object System.Drawing.PointF(($x - 6), 58)))) }
        }
        'mew' {
            # el callejón nocturno de la cinemática de Guillotina, con la farola
            $g.Clear((C 20 16 18))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.62 0.55
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 50 60 10 20))), 0, 0, $W, $H)
            Degradado $g 0 0 420 $H (ARGB 225 28 20 24) (ARGB 160 28 20 24) 0
            Degradado $g 420 0 70 $H (ARGB 160 28 20 24) (ARGB 0 28 20 24) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 14 8 10) (ARGB 200 14 8 10) 90
            # sombra bajo Guillotina
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 470, 236, 250, 26)
            # barra de tinta con arañazos y borde rojo
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 28 21 24))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 40 35))), 0, 52, $W, 4)
            $ar = New-Object System.Drawing.Pen((C 150 60 50), 3); $ar.StartCap = 'Round'; $ar.EndCap = 'Round'
            for ($i = 0; $i -lt 3; $i++) { $g.DrawLine($ar, ($W - 228 + $i * 12), 10, ($W - 240 + $i * 12), 42) }
            $ar.Dispose()
        }
        'oeste' {
            # duelo al atardecer: cielo morado y naranja, sol enorme, mesetas y cactus a contraluz
            $g.Clear((C 40 20 14))
            Pintar-Atardecer $g 400 0 ($W - 400) $H 198 604 50
            Cactus-Silueta $g 438 206 46 (C 92 30 52)
            Cactus-Silueta $g 742 250 170 (C 34 12 24)
            # sombra de Zodiac en el suelo
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 50 14 16))), 530, 240, 140, 16)
            # pared de tablones del saloon detrás de los botones
            for ($x = 0; $x -lt 400; $x += 40) {
                $col = if (($x / 40) % 2 -eq 0) { (C 86 48 26) } else { (C 76 42 22) }
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($col)), $x, 52, 40, ($H - 52))
                $veta = New-Object System.Drawing.Pen((ARGB 60 30 14 6), 1)
                foreach ($f in @(0.25, 0.55, 0.8)) { $vx = $x + 40 * $f; $g.DrawBezier($veta, [float]$vx, 52, [float]($vx + 3), [float]($H * 0.4), [float]($vx - 3), [float]($H * 0.7), [float]$vx, [float]$H) }
                $veta.Dispose()
                $g.DrawLine((New-Object System.Drawing.Pen((C 46 24 10), 2)), $x, 52, $x, $H)
                foreach ($ny in @(62, ($H - 12))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 36 36))), ($x + 17), $ny, 5, 5) }
            }
            Degradado $g 0 52 400 ($H - 52) (ARGB 40 0 0 0) (ARGB 150 10 4 0) 90
            # poste de madera entre el saloon y el desierto
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 96 56 28))), 396, 52, 14, ($H - 52))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 140 90 48))), 398, 52, 3, ($H - 52))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 46 24 10))), 409, 52, 2, ($H - 52))
            # barra de madera del saloon
            $mad = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, 52)), (C 104 62 32), (C 72 40 20), 90)
            $g.FillRectangle($mad, 0, 0, $W, 52); $mad.Dispose()
            $tabla = New-Object System.Drawing.Pen((C 56 30 14), 1)
            foreach ($y in @(17, 35)) { $g.DrawLine($tabla, 0, $y, $W, $y) }
            foreach ($x in @(150, 330, 470, 640)) { $g.DrawLine($tabla, $x, 0, $x, 17); $g.DrawLine($tabla, ($x - 60), 17, ($x - 60), 35); $g.DrawLine($tabla, ($x + 40), 35, ($x + 40), 52) }
            $tabla.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 36 18 8))), 0, 52, $W, 4)
        }
        'pressure' {
            # un pasillo inundado del Hadal Blacksite (captura del juego), donde Sebastian monta su tienda
            $g.Clear((C 6 8 12))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.42
            # aclarar un poco la captura (es muy oscura)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 38 90 170 200))), 0, 0, $W, $H)
            Degradado $g 0 0 420 $H (ARGB 228 8 10 14) (ARGB 165 8 10 14) 0
            Degradado $g 420 0 70 $H (ARGB 165 8 10 14) (ARGB 0 8 10 14) 0
            # luz cálida de su farol detrás de él, y un brillo verde azulado del agua
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(450, 20, 300, 260)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p); $pg.CenterColor = (ARGB 70 255 200 110); $pg.SurroundColors = @((ARGB 0 255 200 110))
            $g.FillPath($pg, $p); $pg.Dispose(); $p.Dispose()
            Degradado $g 400 150 ($W - 400) ($H - 150) (ARGB 0 40 140 150) (ARGB 70 40 140 150) 90
            # cables y una lámpara colgando del techo
            $cab = New-Object System.Drawing.Pen((ARGB 200 20 24 30), 2)
            $g.DrawBezier($cab, 430, 58, 520, 80, 640, 70, 760, 62); $g.DrawLine($cab, 712, 58, 712, 92)
            $cab.Dispose()
            $g.FillPie((New-Object System.Drawing.SolidBrush((C 40 46 54))), 698, 86, 28, 22, 180, 180)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 214 140))), 706, 94, 12, 8)
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(672, 70, 80, 70)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p); $pg.CenterColor = (ARGB 120 255 210 140); $pg.SurroundColors = @((ARGB 0 255 210 140))
            $g.FillPath($pg, $p); $pg.Dispose(); $p.Dispose()
            # barra metálica con franja de peligro
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 8 10 14))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 190 200))), 0, 52, $W, 2)
            $am = New-Object System.Drawing.SolidBrush((C 255 190 70)); $ng = New-Object System.Drawing.SolidBrush((C 8 10 14))
            $g.FillRectangle($am, 0, 54, $W, 4)
            for ($x = -10; $x -lt $W; $x += 14) { $g.FillPolygon($ng, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF($x, 54)), (New-Object System.Drawing.PointF(($x + 6), 54)), (New-Object System.Drawing.PointF(($x + 2), 58)), (New-Object System.Drawing.PointF(($x - 4), 58)))) }
        }
        'dod' {
            # el bosque del mapa Treehouse de Die of Death, de noche
            $g.Clear((C 6 12 8))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.55 0.6
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 4 14 18))), 0, 0, $W, $H)
            Degradado $g 0 150 $W ($H - 150) (ARGB 0 160 200 180) (ARGB 60 160 200 180) 90
            Degradado $g 0 0 420 $H (ARGB 230 4 10 6) (ARGB 165 4 10 6) 0
            Degradado $g 420 0 70 $H (ARGB 165 4 10 6) (ARGB 0 4 10 6) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 2 6 4) (ARGB 200 2 6 4) 90
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 535, 252, 140, 16)
            # barra negra con el logo del juego
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 4 8 6))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 130 91))), 0, 52, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 52 41))), 0, 55, $W, 1)
            $logo = Cargar-Img $k.TituloImg; if ($logo) { $g.DrawImage($logo, 8, 3, 141, 47); $logo.Dispose() }
        }
        'femta' {
            # la ciudad roja de la portada de "ALL THE TIME" (femtanyl), con puntos de imprenta
            $g.Clear((C 12 6 8))
            Imagen-Cubrir $g $k.FondoImg 0 52 $W ($H - 52) 0.5 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 110 40 0 8))), 0, 52, $W, ($H - 52))
            $pt = New-Object System.Drawing.SolidBrush((ARGB 46 0 0 0))
            for ($y = 56; $y -lt $H; $y += 6) { for ($x = (($y / 6) % 2) * 3; $x -lt $W; $x += 6) { $g.FillEllipse($pt, [float]$x, [float]$y, 2.4, 2.4) } }
            $pt.Dispose()
            # panel negro detrás de los botones, con borde blanco como una pegatina
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 10 6 8))), $pan); $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)), $pan); $pan.Dispose()
            # un vinilo asomando detrás de la portada
            $vx = 668; $vy = 160; $vr = 94
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 14 12 14))), ($vx - $vr), ($vy - $vr), (2 * $vr), (2 * $vr))
            $sur = New-Object System.Drawing.Pen((ARGB 50 255 255 255), 0.8)
            for ($rr = 32; $rr -lt $vr - 4; $rr += 6) { $g.DrawEllipse($sur, ($vx - $rr), ($vy - $rr), (2 * $rr), (2 * $rr)) }
            $sur.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 230 20 40))), ($vx - 26), ($vy - 26), 52, 52)
            $g.FillEllipse([System.Drawing.Brushes]::White, ($vx - 3), ($vy - 3), 6, 6)
            # barra de arriba negra con línea roja y el logo en llamas (portada de MAN BITES DOG)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), 0, 49, $W, 3)
            $lg = Cargar-Img $k.Logo; if ($lg) { $g.DrawImage($lg, 300, 2, 78, 46); $lg.Dispose() }
        }
        'punk' {
            # atardecer en el skatepark, como sus dibujos (fondo difuminado)
            $g.Clear((C 250 190 150))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            # panel crema detrás de los botones, con el borde verde en zigzag de sus pegatinas
            Dibujar-Pegatina $g 12 66 386 ($H - 76) (ARGB 215 255 246 236)
            # barra de arriba: los cuadros marrones de su camisa y una línea verde
            Dibujar-Cuadros $g 0 0 $W 50
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 110 235 140))), 0, 50, $W, 4)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 46 34 30))), 0, 54, $W, 2)
            # púa de guitarra verde como logo
            $pua = New-Object System.Drawing.Drawing2D.GraphicsPath
            $pua.AddBezier(12, 16, 22, 10, 32, 10, 38, 16); $pua.AddBezier(38, 16, 38, 26, 30, 34, 25, 40); $pua.AddBezier(25, 40, 20, 34, 12, 26, 12, 16)
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 235 140))), $pua); $g.DrawPath((New-Object System.Drawing.Pen((C 46 34 30), 2)), $pua); $pua.Dispose()
            # pegatina "PUNK RULZZZ"
            $st = $g.Save(); $g.TranslateTransform(440, 26); $g.RotateTransform(-5)
            $pg = Ruta-Redonda (-64) (-13) 128 26 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 235 140))), $pg); $g.DrawPath((New-Object System.Drawing.Pen((C 46 34 30), 2.5)), $pg); $pg.Dispose()
            $tw = Ancho-Texto 'PUNK RULZZZ' 'Arial Black' 13
            Texto-Contorno $g 'PUNK RULZZZ' 'Arial Black' 13 (-$tw / 2) (-10) (C 255 255 255) 3
            $g.Restore($st)
        }
        'pizza' {
            # mantel de pizzería a cuadros y, a la derecha, el Paint donde vive Kevin
            $g.Clear((C 255 255 255))
            $roja = New-Object System.Drawing.SolidBrush((ARGB 110 220 40 40))
            for ($x = 0; $x -lt $W; $x += 40) { $g.FillRectangle($roja, $x, 52, 20, ($H - 52)) }
            for ($y = 52; $y -lt $H; $y += 40) { $g.FillRectangle($roja, 0, $y, $W, 20) }
            $roja.Dispose()
            # migas y trocitos de pizza por el mantel
            $rn = New-Object System.Random 21
            for ($i = 0; $i -lt 5; $i++) { Dibujar-Trozo $g $rn.Next(20, 390) $rn.Next(70, 300) 16 $rn.Next(0, 360) }
            # panel blanco detrás de los botones, con borde de rotulador
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 16
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 255 255 255))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 20 20 20), 2.5)), $pan); $pan.Dispose()
            # la ventana de Paint: barra azul, menú, paleta de colores y lienzo blanco
            $px = 410; $py = 58; $pw = $W - 418; $ph = 214
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), ($px + 5), ($py + 5), $pw, $ph)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 212 208 200))), $px, $py, $pw, $ph)
            Degradado $g $px $py $pw 18 (C 10 36 106) (C 166 202 240) 0
            $g.DrawString('kevin.png - Paint', (FntP('Tahoma', 8, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, ($px + 20), ($py + 2))
            Dibujar-Trozo $g ($px + 10) ($py + 9) 12 180
            foreach ($bi in 0..2) {
                $bx = $px + $pw - 50 + $bi * 16
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 212 208 200))), $bx, ($py + 3), 14, 12)
                $g.DrawRectangle((New-Object System.Drawing.Pen((C 64 64 64), 1)), $bx, ($py + 3), 14, 12)
                $g.DrawString(@('_', '□', 'x')[$bi], (FntP('Tahoma', 7, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, ($bx + 2), ($py + 1))
            }
            $g.DrawString('Archivo   Edición   Ver   Imagen   Colores   Ayuda', (FntP('Tahoma', 7)), [System.Drawing.Brushes]::Black, ($px + 4), ($py + 19))
            $g.FillRectangle([System.Drawing.Brushes]::White, 414, 90, 334, 172)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 128 128 128), 1)), 413, 89, 335, 173)
            # paleta de colores de Paint abajo, con los colores de Kevin primero
            $pal = @((C 0 0 0), (C 70 200 40), (C 30 100 240), (C 255 110 200), (C 255 206 84), (C 206 40 40), (C 128 128 128), (C 255 255 255), (C 128 0 0), (C 128 128 0), (C 0 128 0), (C 0 128 128), (C 0 0 128), (C 128 0 128))
            for ($i = 0; $i -lt $pal.Count; $i++) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($pal[$i])), (416 + $i * 14), 264, 12, 6)
                $g.DrawRectangle((New-Object System.Drawing.Pen((C 90 90 90), 1)), (416 + $i * 14), 264, 12, 6)
            }
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 20 20 20), 2)), $px, $py, $pw, $ph)
            # barra de arriba verde Kevin con franjas rosa y azul
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 200 40))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 110 200))), 0, 46, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 30 100 240))), 0, 49, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 20 20 20))), 0, 52, $W, 2)
            Dibujar-Trozo $g 505 27 26 200
        }
        'pop' {
            # el acuario del videoclip "You're Just Like Pop Music": agua de neón, rayos de luz, plantas y grava de colores
            $g.Clear((C 26 12 48))
            # fondo de la izquierda (detrás de los botones): morado oscuro con un poco de la foto del vídeo
            Imagen-Cubrir $g $k.FondoImg 0 0 404 $H 0.5 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 26 12 48))), 0, 0, 404, $H)
            # el agua: de azul claro arriba a morado profundo abajo
            Degradado $g 404 56 ($W - 404) ($H - 56) (C 96 170 230) (C 40 24 104) 90
            Degradado $g 404 56 ($W - 404) ($H - 56) (ARGB 0 255 92 190) (ARGB 60 255 92 190) 0
            # rayos de luz que entran desde arriba
            foreach ($rx in @(430, 520, 640, 720)) {
                $ray = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$rx, 56)), (New-Object System.Drawing.PointF([float]($rx + 26), 56)), (New-Object System.Drawing.PointF([float]($rx - 30), [float]$H)), (New-Object System.Drawing.PointF([float]($rx - 80), [float]$H)))
                $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 22 255 255 255))), $ray)
            }
            # plantas de acuario (detrás de Tetra)
            $rn = New-Object System.Random 7
            foreach ($px in @(418, 446, 560, 742, 754)) {
                for ($j = 0; $j -lt 4; $j++) {
                    $alto = $rn.Next(60, 150); $bx = $px + $j * 5 - 8
                    $hoja = New-Object System.Drawing.Pen((ARGB 200 40 ($rn.Next(140, 200)) 150), [float]$rn.Next(3, 6)); $hoja.StartCap = 'Round'; $hoja.EndCap = 'Round'
                    $g.DrawBezier($hoja, [float]$bx, 300, [float]($bx + $rn.Next(-14, 14)), [float](300 - $alto * 0.35), [float]($bx + $rn.Next(-18, 18)), [float](300 - $alto * 0.7), [float]($bx + $rn.Next(-10, 10)), [float](300 - $alto))
                    $hoja.Dispose()
                }
            }
            # la grava de colores del fondo del acuario
            Degradado $g 404 290 ($W - 404) 30 (C 60 30 90) (C 30 14 52) 90
            $cols = @((C 255 120 200), (C 90 230 250), (C 255 214 120), (C 190 150 255), (C 255 255 255))
            for ($i = 0; $i -lt 110; $i++) { $gx = $rn.Next(404, $W); $gy = $rn.Next(288, $H); $gs = $rn.Next(3, 7); $cc = $cols[$i % 5]; $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, $cc))), [float]$gx, [float]$gy, [float]$gs, [float]($gs * 0.7)) }
            # el burbujeador (de donde salen las burbujas)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 40 60))), 470, 288, 18, 10); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 90 90 120))), 472, 284, 14, 5)
            # sombra bajo Tetra
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 110 20 0 40))), 610, 306, 124, 12)
            # el cristal del acuario: reflejos y marco de neón
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 26 255 255 255))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(410, 60)), (New-Object System.Drawing.PointF(452, 60)), (New-Object System.Drawing.PointF(412, 140))))
            $g.DrawRectangle((New-Object System.Drawing.Pen((ARGB 120 90 230 250), 2)), 405, 57, ($W - 408), ($H - 59))
            # panel oscuro con borde de neón detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 14
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 190 24 10 46))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 70 255 92 190), 6)), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 230 90 230 250), 2)), $pan); $pan.Dispose()
            # barra de arriba en degradado morado y rosa, con líneas de neón y el logo "Failure" de su gorra como pegatina
            Degradado $g 0 0 $W 52 (C 40 12 70) (C 130 34 116) 0
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 90 230 250))), 0, 49, $W, 2)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 92 190))), 0, 51, $W, 2)
            $lg = Cargar-Img $k.Logo; if ($lg) { $g.DrawImage($lg, 466, 3, 60, 46); $lg.Dispose() }
        }
        'gran' {
            # el remolino de pintura de su intro, oscurecido, con el laboratorio de Antihuman Inc. encima
            $g.Clear((C 8 10 9))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 4 8 6))), 0, 0, $W, $H)
            # panel oscuro con borde verde detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 8 12 10))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 32 208 44), 2)), $pan); $pan.Dispose()
            # monitor del laboratorio donde sale Gran
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 414, 66, 340, 208)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 408, 56, 346, 216)
            # barra de arriba negra con franjas rosas (como el fondo de su cara tapada) y la línea verde
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 52)
            $rosa = New-Object System.Drawing.SolidBrush((ARGB 70 255 70 170))
            for ($x = -60; $x -lt $W; $x += 36) { $g.FillPolygon($rosa, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, 52)), (New-Object System.Drawing.PointF([float]($x + 14), 52)), (New-Object System.Drawing.PointF([float]($x + 66), 0)), (New-Object System.Drawing.PointF([float]($x + 52), 0)))) }
            $rosa.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 32 208 44))), 0, 49, $W, 3)
            # logo: una G verde en un hexágono, el color de Gran en el consejo de Golden City
            $hx = 330; $hy = 26; $hr = 19
            $pts = [System.Drawing.PointF[]]@(0..5 | ForEach-Object { $an = [Math]::PI / 3 * $_ + [Math]::PI / 6; New-Object System.Drawing.PointF([float]($hx + $hr * [Math]::Cos($an)), [float]($hy + $hr * [Math]::Sin($an))) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 10 14 11))), $pts)
            $g.DrawPolygon((New-Object System.Drawing.Pen((C 32 208 44), 2.5)), $pts)
            $tw = Ancho-Texto 'G' 'Arial Black' 18
            Texto-Contorno $g 'G' 'Arial Black' 18 ($hx - $tw / 2 - 1) ($hy - 13) (C 32 208 44) 3
        }
        'evil' {
            # la baseplate de noche con niebla roja (el mapa de la ronda especial)
            $g.Clear((C 10 4 6))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            # panel oscuro con borde rojo detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 8 4 6))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 170 20 30), 2)), $pan); $pan.Dispose()
            # barra de arriba negra con el título "Evil Scary" del juego y la línea roja
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 20 30))), 0, 52, $W, 3)
            $ti = Cargar-Img $k.TituloImg; if ($ti) { $g.DrawImage($ti, 10, 4, 104, 46); $ti.Dispose() }
        }
        'boneyard' {
            # la colina del Boneyard donde se pelea contra Dybbuk (fondo del juego), con la luna y las lápidas
            $g.Clear((C 24 24 28))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.45
            Degradado $g 0 0 420 $H (ARGB 225 26 27 32) (ARGB 160 26 27 32) 0
            Degradado $g 420 0 70 $H (ARGB 160 26 27 32) (ARGB 0 26 27 32) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 12 12 16) (ARGB 200 12 12 16) 90
            # sombra bajo Dybbuk
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), 520, 240, 124, 15)
            # barra de tinta con el borde gris azulado de los fantasmas y la lápida del Boneyard
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 22 23 28))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 142 156))), 0, 52, $W, 4)
            $lp = Cargar-Img $k.Lapida; if ($lp) { $g.DrawImage($lp, 344, 5, 38, 43); $lp.Dispose() }
        }
        'corrupta' {
            # el vacío del multiverso con un portal y píxeles corruptos; la foto de Ellie pegada como una polaroid
            $g.Clear((C 16 6 16))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            Degradado $g 0 0 420 $H (ARGB 230 18 6 18) (ARGB 170 18 6 18) 0
            Degradado $g 420 0 70 $H (ARGB 170 18 6 18) (ARGB 0 18 6 18) 0
            $sf = Cargar-Img $k.Selfie; if ($sf) { Dibujar-Polaroid $g $sf 446 70 86 -7; $sf.Dispose() }
            # barra negra con la línea partida en rosa y cian (como una imagen con glitch)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 10 4 10))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 90 230 255))), 0, 54, $W, 2)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 92 170))), 0, 52, $W, 2)
            $rn = New-Object System.Random 3; $cols = @((C 255 40 80), (C 90 230 255), (C 255 230 60), (C 150 80 255))
            for ($i = 0; $i -lt 14; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($cols[$rn.Next(4)])), [float]$rn.Next(446, 528), [float]$rn.Next(6, 46), [float]$rn.Next(4, 16), [float]$rn.Next(3, 7)) }
        }
        'knight' {
            # fondo de combate de Deltarune: negro con la cuadrícula morada
            $g.Clear([System.Drawing.Color]::Black)
            $p1 = New-Object System.Drawing.Pen((C 52 18 82), 1); $p2 = New-Object System.Drawing.Pen((C 26 8 42), 1)
            for ($x = 0; $x -lt $W; $x += 32) { $g.DrawLine($p1, $x, 54, $x, $H); $g.DrawLine($p2, ($x + 16), 54, ($x + 16), $H) }
            for ($y = 54; $y -lt $H; $y += 32) { $g.DrawLine($p1, 0, $y, $W, $y); $g.DrawLine($p2, 0, ($y + 16), $W, ($y + 16)) }
            # caja de los botones: negra con borde blanco, como los cuadros de texto del juego
            $g.FillRectangle([System.Drawing.Brushes]::Black, 8, 60, 394, ($H - 66))
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)), 8, 60, 394, ($H - 66))
            # barra de arriba negra con una línea blanca
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 52)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, 51, $W, 2)
            # una Fuente Oscura al fondo, detrás del Knight
            $fu = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(640, 56, 40, ($H - 56))), [System.Drawing.Color]::FromArgb(0, 0, 0, 0), (ARGB 70 120 60 200), 90)
            $g.FillRectangle($fu, 640, 56, 40, ($H - 56)); $fu.Dispose()
        }
        'niebla' {
            # la colina de noche con la casita del vídeo, la luna y los pinos
            $g.Clear((C 40 16 70))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.55
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 45 70 0 110))), 0, 0, $W, $H)
            # panel morado translúcido con borde rosa detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 175 46 18 80))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 90 230), 2)), $pan); $pan.Dispose()
            # barra de arriba morada con nubecitas rosas
            Degradado $g 0 0 $W 52 (C 74 28 124) (C 40 14 72) 90
            $nube = New-Object System.Drawing.SolidBrush((ARGB 60 255 180 240))
            foreach ($nx in @(330, 470, 610, 700)) { $g.FillEllipse($nube, $nx, 14, 40, 20); $g.FillEllipse($nube, ($nx + 18), 6, 36, 26); $g.FillEllipse($nube, ($nx + 40), 16, 34, 18) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 90 230))), 0, 50, $W, 3)
        }
        'pintor' {
            # la sala del Blacksite de Painter: paneles de metal, luz lila y cables hacia su tableta
            Pr-Reset
            Pr-Pintar-Fondo $g $W $H
        }
        'clima' {
            # el parte del tiempo de Weathergirl: el azul grisáceo del vídeo y un cielo que cambia con el tiempo de verdad
            Wg-Reset
            Wg-Pintar-Fondo $g $W $H
        }
        'arana' {
            # la guarida de Velvet en el Planeta Gris: cueva morada casi negra, rocas, telarañas y líneas de pantalla CRT (como Gunsaw)
            Degradado $g 0 0 $W $H (C 36 14 32) (C 8 4 8) 90
            $rn = New-Object System.Random 11
            $roca = New-Object System.Drawing.SolidBrush((C 14 6 12))
            for ($i = 0; $i -lt 9; $i++) { $rx = 400 + $i * 44 + $rn.Next(-8, 8); $rh = $rn.Next(18, 46); $g.FillPolygon($roca, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($rx - 30), [float]$H)), (New-Object System.Drawing.PointF([float]($rx + $rn.Next(-10, 10)), [float]($H - $rh))), (New-Object System.Drawing.PointF([float]($rx + 34), [float]$H)))) }
            for ($i = 0; $i -lt 8; $i++) {
                $rx = 400 + $i * 50 + $rn.Next(-10, 10)
                $p1 = New-Object System.Drawing.PointF([float]($rx - 18), 56); $p2 = New-Object System.Drawing.PointF([float]($rx + $rn.Next(-6, 6)), [float](56 + $rn.Next(12, 34))); $p3 = New-Object System.Drawing.PointF([float]($rx + 20), 56)
                $g.FillPolygon($roca, [System.Drawing.PointF[]]@($p1, $p2, $p3))
            }
            $roca.Dispose()
            # resplandor rojo detrás de Velvet
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse(520, 70, 260, 260)
            $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pgb.CenterColor = (ARGB 70 200 20 40); $pgb.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 200 20 40))
            $g.FillPath($pgb, $gp); $pgb.Dispose(); $gp.Dispose()
            # las telarañas: una grande colgada del techo y otra en la esquina
            Vv-Red $g 470 58 250 (ARGB 95 230 225 235) 11 12 168 7
            Vv-Red $g $W 56 150 (ARGB 70 230 225 235) 6 90 180 5
            # panel oscuro con borde rojo detrás de los botones, con una telaraña pequeña en la esquina
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 200 20 8 16))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 200 24 44), 2)), $pan); $pan.Dispose()
            Vv-Red $g 9 61 60 (ARGB 60 230 225 235) 5 0 90 4
            # sombra bajo Velvet
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 130 0 0 0))), 590, 306, 140, 14)
            # líneas de pantalla CRT por toda la escena (como el menú de Gunsaw)
            $lin = New-Object System.Drawing.Pen((ARGB 14 255 255 255), 1); for ($y = 56; $y -lt $H; $y += 3) { $g.DrawLine($lin, 404, $y, $W, $y) }; $lin.Dispose()
            # barra de arriba negra con la línea roja y una arañita
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 10 4 8))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 200 24 44))), 0, 52, $W, 3)
            $sx = 500; $sy = 26; $pat = New-Object System.Drawing.Pen((C 200 24 44), 2)
            foreach ($lado in @(-1, 1)) { foreach ($j in 0..3) { $g.DrawLines($pat, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$sx, [float]($sy - 3 + $j * 3))), (New-Object System.Drawing.PointF([float]($sx + $lado * (9 + $j)), [float]($sy - 9 + $j * 5))), (New-Object System.Drawing.PointF([float]($sx + $lado * (15 + $j * 2)), [float]($sy + 2 + $j * 5))))) } }
            $pat.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 30 8 16))), [float]($sx - 6), [float]($sy - 7), 12, 16)
            $g.DrawEllipse((New-Object System.Drawing.Pen((C 200 24 44), 1.5)), [float]($sx - 6), [float]($sy - 7), 12, 16)
            $g.DrawLine((New-Object System.Drawing.Pen((ARGB 150 230 225 235), 1)), [float]$sx, 0, [float]$sx, [float]($sy - 7))
        }
        'lobo' {
            # la sala de monitores de Angela (fondo del juego), oscurecida a la izquierda para los botones
            $g.Clear((C 10 13 18))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.6 0.5
            Degradado $g 0 0 420 $H (ARGB 230 10 13 18) (ARGB 175 10 13 18) 0
            Degradado $g 420 0 80 $H (ARGB 175 10 13 18) (ARGB 0 10 13 18) 0
            Degradado $g 400 240 ($W - 400) ($H - 240) (ARGB 0 6 8 12) (ARGB 170 6 8 12) 90
            # panel de la consola detrás de los botones: oscuro, borde ámbar y línea turquesa
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 4
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 195 12 16 22))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 170 40), 1.5)), $pan); $pan.Dispose()
            $g.DrawLine((New-Object System.Drawing.Pen((ARGB 150 80 210 200), 1)), 14, 66, 396, 66)
            # hexágonos de L Corp, muy suaves, en el panel
            $hx = New-Object System.Drawing.Pen((ARGB 22 255 176 50), 1)
            for ($q = 0; $q -lt 7; $q++) { $cx = 40 + $q * 56; $cy = 300; $pts = [System.Drawing.PointF[]]@(0..5 | ForEach-Object { $an = [Math]::PI / 3 * $_; New-Object System.Drawing.PointF([float]($cx + 22 * [Math]::Cos($an)), [float]($cy + 22 * [Math]::Sin($an))) }); $g.DrawPolygon($hx, $pts) }
            $hx.Dispose()
            # sombra bajo Angela
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), 616, 304, 120, 14)
            # barra de arriba: negra con la línea ámbar y la turquesa (como la interfaz del juego) y el hexágono de L Corp
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 14 18 24))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 170 40))), 0, 52, $W, 2)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 80 210 200))), 0, 55, $W, 1)
            $hx = 494; $hy = 26
            $pts = [System.Drawing.PointF[]]@(0..5 | ForEach-Object { $an = [Math]::PI / 3 * $_ + [Math]::PI / 6; New-Object System.Drawing.PointF([float]($hx + 19 * [Math]::Cos($an)), [float]($hy + 19 * [Math]::Sin($an))) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 22 26 32))), $pts); $g.DrawPolygon((New-Object System.Drawing.Pen((C 255 170 40), 2)), $pts)
            $tw = Ancho-Texto 'L' 'Bahnschrift' 18
            Texto-Contorno $g 'L' 'Bahnschrift' 18 ($hx - $tw / 2 - 1) ($hy - 12) (C 255 176 50) 2
        }
        'historia' {
            # la Planta de Historia (fondo de sus diálogos en el juego): estanterías con luz dorada, oscurecida a la izquierda
            $g.Clear((C 36 26 16))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            Degradado $g 0 0 420 $H (ARGB 220 30 22 12) (ARGB 160 30 22 12) 0
            Degradado $g 420 0 80 $H (ARGB 160 30 22 12) (ARGB 0 30 22 12) 0
            Degradado $g 400 230 ($W - 400) ($H - 230) (ARGB 0 20 14 8) (ARGB 170 20 14 8) 90
            # panel de cuero con filete dorado detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 8
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 175 38 28 18))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 170 90), 2)), $pan); $pan.Dispose()
            # la mesa de lectura (a la izquierda de Malkuth) y su sombra
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 100 0 0 0))), 628, 304, 116, 14)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), 432, 268, 172, 8)
            Degradado $g 428 252 172 16 (C 128 84 44) (C 86 54 26) 90
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 58 36 16), 1.5)), 428, 252, 172, 16)
            foreach ($px in @(440, 584)) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 78 48 22))), $px, 268, 8, ($H - 268)) }
            # barra de arriba: ocre de la planta, con el emblema de Malkuth
            Degradado $g 0 0 $W 52 (C 120 86 40) (C 72 50 22) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 240 206 120))), 0, 50, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 28 14))), 0, 53, $W, 2)
            $em = Cargar-Img $k.Emblema; if ($em) { $g.DrawImage($em, 474, 3, 48, 47); $em.Dispose() }
        }
        'abismo' {
            # su escondite de la 4ª capa (del anime), oscurecido a la izquierda para los botones
            $g.Clear((C 20 36 24))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.6 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 40 10 30 14))), 0, 0, $W, $H)
            # panel de pergamino detrás de los botones
            $pan = Ruta-Redonda 8 62 394 ($H - 68) 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 20 34 22))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 150 120 90), 2)), $pan); $pan.Dispose()
            # barra de arriba: cuero marrón con una cuerda de silbatos de explorador
            Degradado $g 0 0 $W 52 (C 92 66 46) (C 64 44 30) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 236 170 190))), 0, 50, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 28 20))), 0, 53, $W, 2)
            $cu = New-Object System.Drawing.Pen((C 200 170 120), 1.5)
            $g.DrawBezier($cu, 330, 10, 380, 22, 470, 22, 520, 10); $cu.Dispose()
            $cols = @((C 210 50 50), (C 70 120 210), (C 200 200 220), (C 30 30 34), (C 250 250 250))
            for ($i = 0; $i -lt 5; $i++) { Dibujar-Silbato $g (346 + $i * 34) (18 + [Math]::Sin(($i + 0.5) / 5.0 * [Math]::PI) * 4) $cols[$i] }
        }
        'enfosi' {
            # un mapa del juego (Blibble's Field) de fondo, con la interfaz de Roblox
            $g.Clear((C 120 170 230))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.62
            # panel oscuro translúcido detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 15 18 30))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 200 255 255 255), 2)), $pan); $pan.Dispose()
            # barra de arriba amarilla, como el Giggler, y el logo de los Glaggles
            Degradado $g 0 0 $W 52 (C 255 222 80) (C 250 176 30) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 30 10))), 0, 49, $W, 3)
            $lg = Cargar-Img $k.Logo; if ($lg) { $g.DrawImage($lg, 262, 8, 118, [float]($lg.Height * 118 / $lg.Width)); $lg.Dispose() }
            # sombra de la estatua en el suelo
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), 412, 258, 112, 14)
        }
        'teto' {
            # el rosa del videoclip de BIRDBRAIN, con fotos del vídeo pegadas como en un álbum
            Degradado $g 0 0 $W $H (C 252 226 230) (C 247 208 214) 90
            $ray = New-Object System.Drawing.Pen((ARGB 70 255 255 255), 12)
            for ($x = -$H; $x -lt $W; $x += 40) { $g.DrawLine($ray, $x, 56, ($x + $H), ($H + 56)) }
            $ray.Dispose()
            # barra roja de arriba con franjas amarillas, como sus medias
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 40 64))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 176 24 48))), 0, 48, $W, 4)
            for ($x = 0; $x -lt $W; $x += 24) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 246 204 60))), $x, 52, 12, 6)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 252 232 150))), ($x + 12), 52, 12, 6)
            }
            # panel suave detrás de los botones
            $pan = Ruta-Redonda 8 62 392 ($H - 70) 22
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), $pan); $g.DrawPath((New-Object System.Drawing.Pen((ARGB 140 214 40 64), 2)), $pan); $pan.Dispose()
            # polaroids del videoclip
            $fotos = @($k.Fotos | ForEach-Object { Cargar-Img $_ })
            Dibujar-Polaroid $g $fotos[0] 432 74 96 (-7)
            Dibujar-Polaroid $g $fotos[1] 470 176 84 6
            foreach ($f in $fotos) { if ($f) { $f.Dispose() } }
            # sombra en el suelo bajo Teto
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 55 150 20 40))), 584, 284, 120, 14)
        }
        'zorro' {
            # la casita de Averi: papel pintado a rayas, zócalo de madera y su foto en una polaroid
            Degradado $g 0 0 $W $H (C 255 246 232) (C 252 232 206) 90
            for ($x = 0; $x -lt $W; $x += 28) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 245 210 170))), $x, 56, 12, 190) }
            $pu = New-Object System.Drawing.SolidBrush((ARGB 120 236 150 90))
            for ($y = 70; $y -lt 236; $y += 28) { for ($x = 20; $x -lt $W; $x += 28) { $g.FillEllipse($pu, $x, $y, 5, 5) } }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 128 80))), 0, 238, $W, ($H - 238))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 168 104 62))), 0, 238, $W, 5)
            $lin = New-Object System.Drawing.Pen((C 176 112 70), 1.5)
            for ($x = 30; $x -lt $W; $x += 60) { $g.DrawLine($lin, $x, 246, $x, $H) }
            # panel suave detrás de los botones
            $pan = Ruta-Redonda 8 60 392 246 22
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), $pan); $g.DrawPath((New-Object System.Drawing.Pen((ARGB 120 230 128 56), 2)), $pan); $pan.Dispose()
            # polaroid con sombra y celo
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 90 40 10))), 441, 67, 216, 188)
            $g.FillRectangle([System.Drawing.Brushes]::White, 436, 62, 216, 188)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 226 210 190), 1)), 436, 62, 216, 188)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 226 190))), 446, 72, 196, 147)
            foreach ($tx in @(430, 620)) {
                $st = $g.Save(); $g.TranslateTransform([float]($tx + 20), 64); $g.RotateTransform($(if ($tx -lt 500) { -32 } else { 32 }))
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 255 236 150))), -22, -7, 44, 14); $g.Restore($st)
            }
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString('Averi ♥', (FntP('Segoe Print', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 150 80 40))), (New-Object System.Drawing.RectangleF(436, 220, 216, 28)), $fmt)
            # barra naranja con lunares
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 128 56))), 0, 0, $W, 52)
            $lu = New-Object System.Drawing.SolidBrush((C 240 148 80))
            for ($x = 8; $x -lt $W; $x += 26) { $g.FillEllipse($lu, $x, 8, 6, 6); $g.FillEllipse($lu, ($x + 13), 32, 6, 6) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 100 40))), 0, 52, $W, 4)
        }
    }
    $g.Dispose()
    return $bmp
}
# bocadillos con forma propia (detrás del texto)
function Pintar-Burbuja($g, $k) {
    $b = $k.Burbuja; $x = $b[0] - 6; $y = $b[1] - 4; $w = $b[2] + 12; $h = $b[3] + 8
    switch ($k.Estilo) {
        'culto' {
            # pergamino con los extremos enrollados
            $r = Ruta-Redonda $x $y $w $h 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 236 222 192))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 120 70 40), 2)), $r); $r.Dispose()
            foreach ($ex in @(($x - 6), ($x + $w - 6))) {
                $rr = Ruta-Redonda $ex ($y - 3) 12 ($h + 6) 10
                $g.FillPath((New-Object System.Drawing.SolidBrush((C 214 196 160))), $rr); $g.DrawPath((New-Object System.Drawing.Pen((C 120 70 40), 2)), $rr); $rr.Dispose()
            }
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 170 24 34))), ($x + $w - 26), ($y + $h - 16), 16, 16)
            $g.DrawEllipse((New-Object System.Drawing.Pen((C 110 10 20), 1.5)), ($x + $w - 26), ($y + $h - 16), 16, 16)
        }
        'kaiju' {
            # caja de radio: WMEW 99.9 en directo
            $r = Ruta-Redonda $x $y $w $h 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 14 10 14))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 200 40), 2)), $r); $r.Dispose()
            $t = Ruta-Redonda ($x + 10) ($y - 13) 98 18 8
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 200 40))), $t); $t.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 220 30 30))), ($x + 16), ($y - 9), 9, 9)
            $g.DrawString('WMEW 99.9', (FntP('EdmundMcMillen_INTLv4', 8)), [System.Drawing.Brushes]::Black, ($x + 28), ($y - 13))
        }
        'mew' {
            # nota de papel con borde de tinta irregular, como la interfaz de Mewgenics
            $r2 = New-Object System.Random(5)
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 2), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + $w * 0.5), [float]($y - 2))), (New-Object System.Drawing.PointF([float]($x + $w - 1), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w + 1), [float]($y + $h - 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.4), [float]($y + $h + 1))), (New-Object System.Drawing.PointF([float]($x - 1), [float]($y + $h - 1))))
            $somb = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 4), ($_.Y + 4)) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 14 8 10))), $somb)
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 246 236 210))), $pts)
            $tinta = New-Object System.Drawing.Pen((C 20 14 16), 3); $tinta.LineJoin = 'Round'
            $g.DrawPolygon($tinta, $pts); $tinta.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 200 60 50))), [float]($x + $w - 40), [float]($y - 8), 30, 12)
        }
        'oeste' {
            # cartel de "se busca" clavado con dos clavos
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 30 14 4))), [float]($x + 4), [float]($y + 4), [float]$w, [float]$h)
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)), (C 246 232 196), (C 226 200 150), 90)
            $g.FillRectangle($br, [float]$x, [float]$y, [float]$w, [float]$h); $br.Dispose()
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 150 105 55), 3)), [float]$x, [float]$y, [float]$w, [float]$h)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 80 40), 1)), [float]($x + 4), [float]($y + 4), [float]($w - 8), [float]($h - 8))
            foreach ($nx in @(($x + 10), ($x + $w - 14))) {
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 60 58 62))), [float]$nx, [float]($y + 3), 6, 6)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 170 170 175))), [float]($nx + 1.5), [float]($y + 4), 2, 2)
            }
        }
        'pressure' {
            # subtítulos del juego: caja oscura con el nombre de quien habla
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 4 6 8))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 70 190 200), 1.5)), $r); $r.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 190 200))), [float]$x, [float]($y + 6), 3, [float]($h - 12))
            $t2 = Ruta-Redonda ($x + 10) ($y - 12) 86 16 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 70 190 200))), $t2); $t2.Dispose()
            $g.DrawString('SEBASTIAN', (FntP('Bahnschrift', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 6 10 14))), ($x + 16), ($y - 12))
        }
        'dod' {
            # bocadillo de texto de Die of Death: negro con borde verde
            $r = Ruta-Redonda $x $y $w $h 14
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 2 6 4))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 0 160 110), 2.5)), $r); $r.Dispose()
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 0 160 110))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.62), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + $w * 0.68), [float]($y - 12))), (New-Object System.Drawing.PointF([float]($x + $w * 0.72), [float]($y + 1)))))
        }
        'femta' {
            # pegatina blanca con contorno negro y sombra roja, como las portadas de femtanyl
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float]($x + 4), [float]($y + 4), [float]$w, [float]$h)
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]$x, [float]$y, [float]$w, [float]$h)
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), [float]$x, [float]$y, [float]$w, [float]$h)
        }
        'punk' {
            # bocadillo crema con borde marrón y sombra verde, como una pegatina
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 235 140))), (Ruta-Redonda ($x + 3) ($y + 3) $w $h 12))
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 248 240))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 2)), $r); $r.Dispose()
        }
        'pizza' {
            # bocadillo de cómic dibujado con rotulador, con piquito hacia Kevin
            $r = Ruta-Redonda $x $y $w $h 14
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 120 255 110 200))), (Ruta-Redonda ($x + 4) ($y + 4) $w $h 14))
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $pk = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.70), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.80), [float]($y - 13))), (New-Object System.Drawing.PointF([float]($x + $w * 0.80), [float]($y + 2))))
            $g.FillPolygon([System.Drawing.Brushes]::White, $pk)
            $tinta = New-Object System.Drawing.Pen((C 20 20 20), 2.5); $tinta.LineJoin = 'Round'
            $g.DrawPath($tinta, $r); $r.Dispose(); $g.DrawLines($tinta, $pk); $tinta.Dispose()
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]($x + $w * 0.705), [float]($y - 1), [float]($w * 0.09), 4)
            Dibujar-Trozo $g ($x + $w - 12) ($y + $h - 10) 12 200
        }
        'pop' {
            # bocadillo morado translúcido con borde de neón rosa y cian
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 34 14 64))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 90 255 92 190), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 90 230 250), 1.6)), $r); $r.Dispose()
        }
        'gran' {
            # pantalla oscura de laboratorio con borde verde
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 8 12 10))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 80 32 208 44), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 32 208 44), 1.6)), $r); $r.Dispose()
        }
        'evil' {
            # el cartel de mensaje de Die of Death: caja oscura con borde rojo
            $r = Ruta-Redonda $x $y $w $h 4
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 22 10 12))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 170 20 30), 2)), $r); $r.Dispose()
        }
        'boneyard' {
            # nota de papel con borde de tinta irregular (la interfaz de Mewgenics) y un celo gris azulado
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 1), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.55), [float]($y - 1))), (New-Object System.Drawing.PointF([float]($x + $w), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + $w + 1), [float]($y + $h - 1))), (New-Object System.Drawing.PointF([float]($x + $w * 0.35), [float]($y + $h + 1))), (New-Object System.Drawing.PointF([float]($x - 1), [float]($y + $h - 2))))
            $somb = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 4), ($_.Y + 4)) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 10 10 14))), $somb)
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 238 236 226))), $pts)
            $tinta = New-Object System.Drawing.Pen((C 22 22 26), 3); $tinta.LineJoin = 'Round'
            $g.DrawPolygon($tinta, $pts); $tinta.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 150 172 186))), [float]($x + 14), [float]($y - 8), 30, 12)
        }
        'corrupta' {
            # caja oscura con borde rosa y una copia cian desplazada (efecto glitch)
            $r = Ruta-Redonda ($x + 2) ($y + 2) $w $h 6
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 200 90 230 255), 2)), $r); $r.Dispose()
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 26 8 24))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 92 170), 2)), $r); $r.Dispose()
        }
        'knight' {
            # cuadro de texto de Deltarune: negro con doble borde blanco
            $g.FillRectangle([System.Drawing.Brushes]::Black, [float]$x, [float]$y, [float]$w, [float]$h)
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)), [float]$x, [float]$y, [float]$w, [float]$h)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 120 120), 1)), [float]($x + 3), [float]($y + 3), [float]($w - 6), [float]($h - 6))
        }
        'niebla' {
            # bocadillo morado con borde rosa neón que brilla un poco
            $r = Ruta-Redonda $x $y $w $h ([Math]::Min(14, $h / 2))
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 60 24 100))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 70 255 90 230), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 90 230), 1.6)), $r); $r.Dispose()
        }
        'pintor' {
            # aviso amarillo, como los consejos que salían al dejar el ratón quieto
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), ($x + 3), ($y + 3), $w, $h)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 255 225))), $x, $y, $w, $h)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 0 0), 1)), $x, $y, $w, $h)
        }
        'clima' {
            # rótulo de la tele: papel blanco con una franja azul a la izquierda
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 10 14 40))), ($x + 3), ($y + 3), $w, $h)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 242 248 249 253))), $x, $y, $w, $h)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 63 91 217))), $x, $y, 5, $h)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 38 48 92), 1)), $x, $y, $w, $h)
        }
        'arana' {
            # bocadillo oscuro con borde rojo y una telarañita en la esquina
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), (Ruta-Redonda ($x + 3) ($y + 3) $w $h 8))
            $r = Ruta-Redonda $x $y $w $h 8
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 232 22 10 18))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 200 24 44), 1.6)), $r); $r.Dispose()
            Vv-Red $g ($x + $w) $y 22 (ARGB 120 230 225 235) 4 90 180 3
        }
        'lobo' {
            # subtítulo de la interfaz de L Corp: caja oscura, barra ámbar a la izquierda y la pestaña ANGELA
            $r = Ruta-Redonda $x $y $w $h 4
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 10 13 18))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 170 40), 1.5)), $r); $r.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 170 40))), [float]$x, [float]($y + 5), 3, [float]($h - 10))
            $t2 = Ruta-Redonda ($x + 10) ($y - 12) 66 16 4
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 170 40))), $t2); $t2.Dispose()
            $g.DrawString('ANGELA', (FntP('Bahnschrift', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 12 14 18))), ($x + 18), ($y - 12))
        }
        'historia' {
            # ficha de catálogo de la biblioteca: cartulina crema, una línea roja arriba y un marcapáginas
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), (Ruta-Redonda ($x + 3) ($y + 3) $w $h 4))
            $r = Ruta-Redonda $x $y $w $h 4
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 250 242 222))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 150 110 50), 1.6)), $r); $r.Dispose()
            $g.DrawLine((New-Object System.Drawing.Pen((ARGB 150 200 60 50), 1)), [float]($x + 4), [float]($y + 4), [float]($x + $w - 30), [float]($y + 4))
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 200 50 45))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w - 24), [float]($y - 6))), (New-Object System.Drawing.PointF([float]($x + $w - 14), [float]($y - 6))), (New-Object System.Drawing.PointF([float]($x + $w - 14), [float]($y + 12))), (New-Object System.Drawing.PointF([float]($x + $w - 19), [float]($y + 8))), (New-Object System.Drawing.PointF([float]($x + $w - 24), [float]($y + 12)))))
        }
        'abismo' {
            # nota de papel de explorador, con una esquina doblada
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), (Ruta-Redonda ($x + 3) ($y + 3) $w $h 6))
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 246 236 212))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 120 92 66), 1.6)), $r); $r.Dispose()
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 220 200 168))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w - 12), [float]$y)), (New-Object System.Drawing.PointF([float]($x + $w), [float]($y + 12))), (New-Object System.Drawing.PointF([float]($x + $w - 12), [float]($y + 12)))))
        }
        'enfosi' {
            # bocadillo blanco del chat de Roblox, con piquito hacia la estatua
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 60 0 0 0))), (Ruta-Redonda ($x + 2) ($y + 3) $w $h 12))
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 190 190 200), 1.5)), $r); $r.Dispose()
            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 20), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + 26), [float]($y - 10))), (New-Object System.Drawing.PointF([float]($x + 40), [float]($y + 1)))))
        }
        'teto' {
            # bocadillo blanco con borde rojo y piquito hacia Teto
            $r = Ruta-Redonda $x $y $w $h 16
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 70 176 24 48))), (Ruta-Redonda ($x + 3) ($y + 4) $w $h 16))
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $pk = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.66), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.74), [float]($y - 11))), (New-Object System.Drawing.PointF([float]($x + $w * 0.78), [float]($y + 2))))
            $g.FillPolygon([System.Drawing.Brushes]::White, $pk)
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 40 64), 2.5)), $r); $r.Dispose()
            $g.DrawLines((New-Object System.Drawing.Pen((C 214 40 64), 2.5)), $pk)
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]($x + $w * 0.665), [float]($y - 1), [float]($w * 0.11), 4)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 246 204 60))), [float]($x + $w - 16), [float]($y + 5), 8, 8)
        }
        'zorro' {
            # nube de diálogo con piquito hacia la foto
            $r = Ruta-Redonda $x $y $w $h 22
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.55), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.62), [float]($y - 12))), (New-Object System.Drawing.PointF([float]($x + $w * 0.68), [float]($y + 2)))))
            $g.DrawPath((New-Object System.Drawing.Pen((C 230 128 56), 2.5)), $r); $r.Dispose()
            $g.DrawLines((New-Object System.Drawing.Pen((C 230 128 56), 2.5)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.55), [float]$y)), (New-Object System.Drawing.PointF([float]($x + $w * 0.62), [float]($y - 12))), (New-Object System.Drawing.PointF([float]($x + $w * 0.68), [float]$y))))
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]($x + $w * 0.56), [float]($y - 1), [float]($w * 0.11), 4)
        }
    }
}
# texto con colores: {r} rojo, {g} verde, {b} blanco
function Texto-Marcado($g, $txt, $f, $x, $y) {
    $cols = @{ r = (C 230 40 50); g = (C 40 220 60); b = (C 226 222 230) }
    $col = $cols.b; $px = [float]$x
    $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    foreach ($trozo in ([regex]::Split($txt, '(\{[rgb]\})'))) {
        if ($trozo -match '^\{([rgb])\}$') { $col = $cols[$Matches[1]]; continue }
        if (-not $trozo) { continue }
        $g.DrawString($trozo, $f, (New-Object System.Drawing.SolidBrush($col)), $px, [float]$y, $sf)
        $px += $g.MeasureString($trozo, $f, (New-Object System.Drawing.PointF(0, 0)), $sf).Width
    }
}
$script:bmpHex = $null; $script:bmpHexIntro = $null; $script:bmpPapel = $null; $script:bmpCasa = $null; $script:bmpDesierto = $null

# ================= DIÁLOGOS (máquina de escribir + boca de Angela) =================
$script:twTexto = ''; $script:twPos = 0; $script:twTick = 0; $script:twInicio = 0
# mensajes importantes: mientras se escriben (y un rato para leerlos) nadie los pisa
$script:twBloqueo = 0; $script:twForzar = $false
$twTimer = New-Object System.Windows.Forms.Timer
$twTimer.Interval = 30
$twTimer.Add_Tick({
    if (-not $script:status -or (Ocupado)) { return }
    $script:twTick++
    $escribiendo = $script:twPos -lt $script:twTexto.Length
    if ($escribiendo) {
        $objetivo = [int](([Environment]::TickCount - $script:twInicio) / 30.0 * $script:skin.Velocidad)
        $script:twPos = [Math]::Min($script:twTexto.Length, [Math]::Max($script:twPos + $script:skin.Velocidad, $objetivo))
    }
    $txt = $script:twTexto.Substring(0, $script:twPos)
    if ($script:skin.Estilo -eq 'hacker' -and ($escribiendo -or ([Math]::Floor($script:twTick / 15) % 2 -eq 0))) { $txt += '_' }
    if ($script:status.Text -ne $txt) { $script:status.Text = $txt; Ajustar-Texto }
    Leer-Texto $escribiendo
    # personajes dibujados que hablan cambiando de boca (campo Habla de la skin: actor y bocas en orden)
    $hb = $script:skin.Habla
    if ($hb) {
        $a = $script:actores[$hb.Id]
        if ($a -and $a.Hasta -eq 0) {
            $pose = if ($escribiendo) { $hb.Bocas[[int][Math]::Floor($script:twTick / 3) % $hb.Bocas.Count] } else { 'main' }
            if ($a.Pose -ne $pose -and $a.Imgs[$pose]) { $a.Pose = $pose; $a.Frame = 0; Seleccionar-Frame $a; Invalidar-Escena }
        }
    }
    # Angela mueve la boca mientras escribe
    if ($script:pb -and $script:caras.Count -gt 0 -and -not $script:dInvitadoHabla) {
        $set = $script:caras[$script:caraModo]
        $img = if ($escribiendo -and ([Math]::Floor($script:twTick / 3) % 2 -eq 1)) { $set[1] } else { $set[0] }
        if ($script:pb.Image -ne $img) { $script:pb.Image = $img }
    }
})

function Decir($texto, $cara) {
    # si hay un mensaje importante a medias, las frases normales esperan su turno
    if ([Environment]::TickCount -lt $script:twBloqueo -and -not $script:twForzar) { return }
    $script:twTexto = [string]$texto; $script:twPos = 0; $script:twInicio = [Environment]::TickCount
    $script:textoManual = $false; $script:leerT = 0
    $k = $script:skin
    # la Cabra y el Cordero ponen voz a lo que dicen (si no acaba de sonar otra cosa)
    if ($k.Estilo -eq 'culto' -and ([Environment]::TickCount - $script:ultimoSonido) -gt 700) { Voz-Culto $texto }
    # Teto dice con su voz una palabra de lo que pone en el bocadillo
    if ($k.Estilo -eq 'teto') { Voz-Teto $texto }
    # Angela pone la cara que pide la frase (la boca la mueve Ag-Tick)
    if ($k.Estilo -eq 'lobo') { Ag-Cara-Decir $cara }
    # Averi cambia de cara según cómo se siente
    if ($k.Estilo -eq 'zorro') {
        $pose = switch ($cara) { 'abiertos' { 'feliz' } 'serio' { 'antojo' } default { if ($script:antojo -ge 100) { 'antojo' } else { 'main' } } }
        Actor-Pose 'A' $pose 0
    }
    if ($script:caras.Count -gt 0) {
        if (-not $cara) { $cara = @('cerrados', 'abiertos')[$Rnd.Next(2)] }
        $script:caraModo = $cara
    }
}

# frase importante: no la corta ninguna otra hasta que se ha escrito y ha dado tiempo a leerla
function Decir-Fijo($texto, $cara, $extra = 3000) {
    $script:twForzar = $true
    try { Decir $texto $cara } finally { $script:twForzar = $false }
    $ms = ([string]$texto).Length * 30 / [Math]::Max(1, $script:skin.Velocidad)
    $script:twBloqueo = [Environment]::TickCount + [int]$ms + $extra
}
function Saludo {
    $k = $script:skin
    if ($k.Estilo -eq 'teto' -and $Rnd.Next(2) -eq 0) {
        $h = (Get-Date).Hour
        if ($h -ge 6 -and $h -lt 13) { return '¡Good morning! ...es "buenos días" en inglés. ¡Buenos días!' }
        elseif ($h -ge 21 -or $h -lt 6) { return '¡Good night! ...ah, no, que acabas de llegar. ¡Buenas noches igual! ¿No deberías dormir?' }
    }
    if ($k.Estilo -eq 'web' -and $Rnd.Next(2) -eq 0) {
        $h = (Get-Date).Hour
        if ($h -lt 6) { return 'Son las tantas. Deberías dormir. Pero bueno, ¿qué abro?' }
        elseif ($h -lt 13) { return 'Buenos días. O eso dicen.' }
        elseif ($h -lt 20) { return 'Buenas tardes. ¿Qué toca ahora?' }
        else { return 'Buenas noches. Bueno, no tan buenas, sigues aquí.' }
    }
    return (Azar $k.Hola)
}

function Mensaje-Entrada($prev) {
    if ($prev -and $script:skin.AlVenirDe -and $script:skin.AlVenirDe[$prev]) { return $script:skin.AlVenirDe[$prev] }
    return (Saludo)
}

# lo que la skin actual opina de otra skin
function Opinion($nombre) {
    $k = $script:skin
    if ($nombre -eq $script:skinNombre) { return (Azar $k.Yo) }
    return (Azar $k.Opina[$nombre])
}
function Opinion-Azar {
    # solo skins de las que la actual tiene opinión escrita (Ellie no opina de nadie ni las demás de ella)
    $k = $script:skin
    $otras = @($Skins.Keys | Where-Object { $_ -ne $script:skinNombre -and $k.Opina -and $k.Opina[$_] })
    if ($otras.Count -eq 0) { return (Azar $k.Idle) }
    return (Opinion (Azar $otras))
}

# ================= BOCADILLO CON TEXTO DESPLAZABLE =================
# El texto va dentro de una caja: si no cabe, sigue la última línea mientras se escribe,
# luego vuelve al principio y baja despacio. También se mueve con la rueda del ratón.
$script:caja = $null; $script:textoManual = $false; $script:leerT = 0
function Montar-Caja-Texto {
    $l = $script:status
    $c = New-Object CajaTexto
    $c.Location = $l.Location; $c.Size = $l.Size
    $c.BackColor = $l.BackColor; $c.BorderStyle = $l.BorderStyle
    $l.BorderStyle = 'None'
    $form.Controls.Remove($l)
    $l.Location = New-Object System.Drawing.Point(0, 0)
    $l.Size = New-Object System.Drawing.Size(($c.ClientSize.Width), ($c.ClientSize.Height))
    $l.BackColor = [System.Drawing.Color]::Transparent
    $c.Controls.Add($l)
    $c.Add_MouseWheel({ Desplazar-Texto $_.Delta })
    $c.Add_MouseEnter({ $this.Focus() })
    $l.Add_MouseEnter({ if ($script:caja) { [void]$script:caja.Focus() } })
    $l.Add_MouseWheel({ Desplazar-Texto $_.Delta })
    $c.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
    $form.Controls.Add($c)
    $script:caja = $c
}
function Ajustar-Texto {
    $c = $script:caja; $l = $script:status; if (-not $c -or -not $l) { return }
    $ancho = [Math]::Max(10, $c.ClientSize.Width - $l.Padding.Horizontal)
    if ($l.UseCompatibleTextRendering) {
        $g = $l.CreateGraphics(); $alto = [int][Math]::Ceiling($g.MeasureString(($l.Text + ' '), $l.Font, $ancho).Height); $g.Dispose()
    } else {
        $alto = [System.Windows.Forms.TextRenderer]::MeasureText(($l.Text + ' '), $l.Font, (New-Object System.Drawing.Size($ancho, 100000)), ([System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl)).Height
    }
    $alto += $l.Padding.Vertical + 6
    $h = [Math]::Max($c.ClientSize.Height, $alto)
    if ($l.Width -ne $c.ClientSize.Width) { $l.Width = $c.ClientSize.Width }
    if ($l.Height -ne $h) { $l.Height = $h }
    if (-not $script:textoManual) { $l.Top = $c.ClientSize.Height - $h }
}
function Desplazar-Texto($delta) {
    $c = $script:caja; $l = $script:status; if (-not $c) { return }
    $script:textoManual = $true
    $paso = [int]($l.Font.Height * 1.2) * [Math]::Sign($delta)
    $l.Top = [int][Math]::Min(0, [Math]::Max($c.ClientSize.Height - $l.Height, $l.Top + $paso))
}
# cuando termina de escribirse un texto largo: vuelve al principio y baja despacio
function Leer-Texto($escribiendo) {
    $c = $script:caja; $l = $script:status
    if (-not $c -or $escribiendo -or $script:textoManual -or $l.Height -le $c.ClientSize.Height) { return }
    $script:leerT++
    if ($script:leerT -eq 45) { $l.Top = 0 }
    elseif ($script:leerT -gt 85 -and ($script:leerT % 2) -eq 0) {
        $min = $c.ClientSize.Height - $l.Height
        if ($l.Top -gt $min) { $l.Top = [Math]::Max($min, $l.Top - [Math]::Max(1, [int]$script:K)) }
    }
}
# ================= CARAS DEL ASISTENTE =================
function Img-Base {
    if ($script:skin.Estilo -eq 'kaiju' -and $script:kFin -and $script:kGanadora -eq 'Z') { return $null }
    if ($script:skin.Estilo -eq 'mew') {
        if (-not $script:gVivo) { return $null }
        if ($script:gFase2) { return $script:imgs.fase2 }
    }
    return $script:imgs.main
}
$caraTimer = New-Object System.Windows.Forms.Timer
$caraTimer.Add_Tick({ $caraTimer.Stop(); if ($script:pb) { $script:pb.Image = (Img-Base) } })
function Cara($clave, $ms) {
    if ($script:actorIds.Count -ge 1) { Actor-Pose $script:actorIds[0] $clave $ms; return }
    if (-not $script:pb -or -not $script:imgs[$clave]) { return }
    $tvTimer.Stop()
    $script:pb.Image = $script:imgs[$clave]
    $caraTimer.Stop(); $caraTimer.Interval = $ms; $caraTimer.Start()
}

# pequeño corte de señal en la tele de Static Miku
$script:tvPaso = 0
$tvTimer = New-Object System.Windows.Forms.Timer
$tvTimer.Interval = 50
$tvTimer.Add_Tick({
    $script:tvPaso--
    if ($script:tvPaso -le 0 -or -not $script:pb) {
        $tvTimer.Stop()
        if ($script:pb) { $script:pb.Image = (Img-Base) }
        return
    }
    Llenar-Ruido $script:tvRuido
    $script:pb.Invalidate()
})
function Corte-Senal($ticks) {
    if ($script:aj.Epilepsia) { return }   # modo seguro: sin estática
    if (-not $script:pb -or -not $script:tvRuido) { return }
    $caraTimer.Stop()
    $script:pb.Image = $script:tvRuido
    $script:tvPaso = $ticks
    $tvTimer.Start()
}

# ================= GUILLOTINA: VIDA Y FURIA =================
$script:gHP = 400; $script:gMax = 400; $script:gFase2 = $false; $script:gVivo = $true
$revTimer = New-Object System.Windows.Forms.Timer
$revTimer.Interval = 5000
$revTimer.Add_Tick({
    $revTimer.Stop()
    if ($script:skin.Estilo -ne 'mew') { return }
    $script:gHP = 400; $script:gMax = 400; $script:gFase2 = $false; $script:gVivo = $true
    if ($script:pb) { $script:pb.Image = (Img-Base) }
    $a = $script:actores['G']; if ($a) { $a.Visible = $true; $a.Alfa = 1.0; $a.Base = 'main'; Actor-Pose 'G' 'clic' 2600 }
    Sonido 'intro'; Sacudir $form 10
    Decir 'WMEW 99.9: ¡Guillotina ha vuelto, buscando venganza!'
    $form.Invalidate()
})
$script:gComidos = 0
function Golpe-Guillotina {
    if (-not $script:gVivo) { Decir '*Ya no está. Pero volverá.*'; return }
    $d = $Rnd.Next(15, 41)
    $script:gHP -= $d
    Actor-Golpe 'G'
    Flotante "-$d" $Rnd.Next(540, 620) $Rnd.Next(90, 130) (C 255 90 70) 32 'EdmundMcMillen_INTLv4'
    if (-not $script:gFase2 -and $script:gHP -le 200) {
        # igual que en el juego: se enfurece, cura 50 y gana 100 de vida máxima
        $script:gFase2 = $true; $script:gHP += 50; $script:gMax += 100
        $a = $script:actores['G']; if ($a) { $a.Base = 'furiosa' }
        Sonido 'furia'; Sonido 'intro'; Cara 'clic' 2600; Sacudir $form 14
        Flotante '¡FURIOSA!' 500 96 (C 255 60 40) 42 'EdmundMcMillen_INTLv4'
        Decir 'WMEW 99.9: ¡Está FURIOSA! ¡Recupera 50 de vida y crece todavía más!'
    } elseif ($script:gHP -le 0) {
        $script:gHP = 0; $script:gVivo = $false
        Sonido 'muere'
        if ($script:pb) { $caraTimer.Stop(); $script:pb.Image = $null }
        $a = $script:actores['G']; if ($a) { $a.Visible = $false }
        Flotante 'K.O.' 540 110 (C 255 60 50) 48 'EdmundMcMillen_INTLv4'
        Decir '*Guillotina cae rodando...* ¡La has derrotado! Por ahora.'
        $revTimer.Start()
    } else {
        if ($script:gFase2) { Sonido 'golpef' } else { Sonido 'golpe' }
        Cara 'herida' 1300
        Decir "-$d HP. $(Azar $script:skin.Clic)"
    }
    $form.Invalidate()
}
# ataques y gestos de Guillotina (en reposo o al abrir apps)
function Guillotina-Ataque($tipo, $texto) {
    if (-not $script:gVivo -or (Ocupado)) { return }
    switch ($tipo) {
        'come' {
            $script:gComidos++
            if ($script:gFase2) { Cara 'inhalaf' 2600 } else { Cara 'inhala' 2600 }
            Sonido 'comer'; Flotante '*ÑAM*' 470 100 (C 255 236 200) 30 'EdmundMcMillen_INTLv4'
        }
        'lanza' { Cara 'lanza' 2200; Sonido 'lanza'; Flotante '¡ALLÁ VA!' 520 90 (C 255 236 200) 26 'EdmundMcMillen_INTLv4' }
        'digiere' { Cara 'digiere' 2600; Sonido 'digiere'; Flotante '*BURP*' 560 110 (C 200 240 140) 28 'EdmundMcMillen_INTLv4' }
        'barriga' { Cara 'barriga' 2000; Sonido 'barriga'; Sacudir $form 12; Flotante '¡BUM!' 540 150 (C 255 120 60) 40 'EdmundMcMillen_INTLv4' }
    }
    if ($texto) { Decir $texto }
    $form.Invalidate()
}

# ================= MIKAELA: SNIPE, HITMARKERS, SMOKEBOMB Y DO THE DEW =================
$script:snApuntando = $false; $script:snCarga = 0; $script:snPos = New-Object System.Drawing.Point(95, 75)
$script:hits = New-Object System.Collections.ArrayList; $script:flash = 0
$script:hitsTotal = 0; $script:dew = 0; $script:lanzadas = 0

$fxTimer = New-Object System.Windows.Forms.Timer
$fxTimer.Interval = 40
$fxTimer.Add_Tick({
    for ($i = $script:hits.Count - 1; $i -ge 0; $i--) { $script:hits[$i].T--; if ($script:hits[$i].T -le 0) { $script:hits.RemoveAt($i) } }
    if ($script:flash -gt 0) { $script:flash-- }
    if ($script:pb) { $script:pb.Invalidate() }
    if ($script:hits.Count -eq 0 -and $script:flash -eq 0 -and -not $script:snApuntando) { $fxTimer.Stop() }
})
function Nuevo-Hit($x, $y) { [void]$script:hits.Add(@{ X = $x; Y = $y; T = 14 }); $fxTimer.Start() }

$snTimer = New-Object System.Windows.Forms.Timer
$snTimer.Interval = 100
$snTimer.Add_Tick({
    $script:snCarga++
    if ($script:snCarga -eq 20) { Sonido 'carga'; Decir 'CHARGED.' }
    if ($script:snCarga -eq 60) { Sonido 'sobrecarga'; Decir 'OVERCHARGED. Esto va a doler.' }
    $form.Invalidate()
})
function Snipe-Inicio {
    if ((Ocupado) -or $script:snApuntando) { return }
    $script:snApuntando = $true; $script:snCarga = 0
    Sonido 'apuntar'; Decir 'Apuntando... (suelta para disparar)'
    $snTimer.Start(); $fxTimer.Start()
}
function Snipe-Disparo {
    if (-not $script:snApuntando) { return }
    $snTimer.Stop(); $script:snApuntando = $false
    # igual que en el juego: 0.5s sin cargar, 1.5s cargado (2s) y 2.5s sobrecargado (6s)
    if ($script:snCarga -ge 60) { $stun = '2.5'; Sonido 'disparoMax' } elseif ($script:snCarga -ge 20) { $stun = '1.5'; Sonido 'disparo' } else { $stun = '0.5'; Sonido 'disparo' }
    Nuevo-Hit $script:snPos.X $script:snPos.Y
    $script:flash = 4; $script:hitsTotal++
    Decir "¡Stun de ${stun}s! $(Azar $script:skin.Clic)"
    $form.Invalidate()
}
$humoTimer = New-Object System.Windows.Forms.Timer
$humoTimer.Interval = 3000
$humoTimer.Add_Tick({ $humoTimer.Stop(); $form.Opacity = (Opacidad-Base) })

# ================= ZODIAC: REVÓLVER DE 6 BALAS =================
$script:balas = 6; $script:disparos = 0; $script:rotTambor = 0.0; $script:fogonazo = 0
$script:agujeros2 = New-Object System.Collections.ArrayList
function Zodiac-Disparo {
    if ($script:balas -gt 0) {
        $script:balas--; $script:disparos++; $script:rotTambor += 60; $script:fogonazo = 4
        Sonido 'bang'; if ($Rnd.Next(2) -eq 0) { Sonido 'grito' }
        Cara 'clic' 1300; Sacudir $form 5
        # agujero de bala en algún sitio del paisaje
        [void]$script:agujeros2.Add(@{ X = [double]$Rnd.Next(410, 740); Y = [double]$Rnd.Next(70, 240); T = 220 })
        Flotante '¡BANG!' $Rnd.Next(440, 640) $Rnd.Next(70, 120) (C 255 220 90) 34 'EdmundMcMillen_INTLv4'
        $form.Invalidate(); return $true
    }
    Cara 'vacio' 1800; Sonido 'vacio'
    Flotante '*click*' 560 100 (C 250 236 205) 24 'EdmundMcMillen_INTLv4'
    return $false
}
# ---- duelo al mediodía: cuando sale "DRAW!", haz clic en Zodiac antes de que dispare ----
$script:duelo = $null; $script:duelosG = 0; $script:duelosP = 0
function Zodiac-Duelo {
    if ($script:duelo -or (Ocupado)) { return }
    $script:duelo = @{ Fase = 'espera'; T = $Rnd.Next(30, 80); Ini = 0 }
    Sonido 'viento'; Cara 'pose' 0
    Decir '¡DUELO! Cuando salga "DRAW!", haz clic en mí. Ni un segundo antes, forastero.'
    $form.Invalidate()
}
function Zodiac-Duelo-Tick {
    $d = $script:duelo
    if ($d.Fase -eq 'espera') {
        $d.T--
        if ($d.T -le 0) { $d.Fase = 'draw'; $d.T = 0; $d.Ini = [Environment]::TickCount; Sonido 'grito'; Sacudir $form 3 }
    } elseif ($d.Fase -eq 'draw') {
        $d.T++
        # Zodiac desenfunda a los 0,9 segundos
        if (([Environment]::TickCount - $d.Ini) -gt 900) { Zodiac-Duelo-Fin 'lento' }
    }
}
function Zodiac-Duelo-Fin($como) {
    $d = $script:duelo; $script:duelo = $null
    switch ($como) {
        'gana' {
            $ms = [Environment]::TickCount - $d.Ini; $script:duelosG++
            Sonido 'bang'; Sonido 'dolor'; Cara 'muere' 2600; Sacudir $form 6; $script:fogonazo = 4
            Flotante ("¡GANASTE!  {0:0.00} s" -f ($ms / 1000.0)) 470 90 (C 255 214 90) 30 'EdmundMcMillen_INTLv4'
            $l = if ($ms -lt 300) { 'Eso ha sido... imposible. ¿Eres un fantasma?' } elseif ($ms -lt 450) { 'Rápido. Muy rápido. Me caigo con estilo.' } else { 'Por los pelos, forastero. Por los pelos.' }
            Decir-Fijo ("*Cae al suelo muy dramáticamente.* $l")
        }
        'lento' {
            $script:duelosP++; $script:disparos++; $script:fogonazo = 4
            Sonido 'bang'; Sonido 'loco'; Cara 'clic' 1600; Sacudir $form 8
            [void]$script:agujeros2.Add(@{ X = [double]$Rnd.Next(420, 520); Y = [double]$Rnd.Next(80, 220); T = 220 })
            Flotante '¡BANG!' 520 90 (C 255 220 90) 34 'EdmundMcMillen_INTLv4'
            Decir (Azar @('Demasiado lento, forastero. *Sopla el humo del cañón.*', '*BANG* En el desierto, el lento se queda sin sombrero.', 'Te has dormido. Yo no duermo. Nunca. Por eso estoy así.'))
        }
        'trampa' {
            $script:duelosP++; $script:disparos++; $script:fogonazo = 4
            Sonido 'bang'; Sonido 'grito'; Cara 'clic' 1600; Sacudir $form 10
            Flotante '¡TRAMPOSO!' 450 90 (C 235 46 34) 32 'EdmundMcMillen_INTLv4'
            Decir '¡TRAMPOSO! Aún no había salido DRAW. *BANG* Eso por listo.'
        }
    }
    $form.Invalidate()
}
function Zodiac-Clic {
    $k = $script:skin
    if ($script:duelo) { if ($script:duelo.Fase -eq 'draw') { Zodiac-Duelo-Fin 'gana' } else { Zodiac-Duelo-Fin 'trampa' }; return }
    if ($script:balas -eq 6 -and $Rnd.Next(3) -eq 0) { Zodiac-Duelo; return }
    if ($script:balas -lt 6) {
        $script:balas = 6; $script:rotTambor += 180
        Cara 'recarga' 1500; Sonido 'recarga'; Sonido 'recargav'
        Decir '*Recarga el revólver.* Seis balas. Que empiece el baile.'
        $form.Invalidate()
    } else { Cara 'pose' 3000; Sonido 'loco'; Decir (Azar $k.Clic) }
}
function Zodiac-Mover {
    if ($script:duelo) { Zodiac-Duelo-Fin $(if ($script:duelo.Fase -eq 'draw') { 'lento' } else { 'trampa' }); return }
    if (Zodiac-Disparo) { Decir '¡NO TE MUEVAS! *BANG*' } else { Decir '¡NO TE MUEVAS! *click*... ¿sin balas? Qué vergüenza.' }
}

# ================= VELVET: TELARAÑAS =================
$script:telarana = $null; $script:telas = 0
$telTimer = New-Object System.Windows.Forms.Timer
$telTimer.Interval = 25000
$telTimer.Add_Tick({ $telTimer.Stop(); $script:telarana = $null; if ($script:grid) { foreach ($c in $script:grid.Controls) { $c.Invalidate() } } })
function Velvet-Escupir {
    $btns = @($script:grid.Controls | Where-Object { $_.Tag -is [hashtable] })
    if ($btns.Count -eq 0) { return $false }
    $b = $btns[$Rnd.Next($btns.Count)]
    $script:telarana = $b.Tag; $script:telas++
    foreach ($c in $script:grid.Controls) { $c.Invalidate() }
    $telTimer.Stop(); $telTimer.Start()
    $form.Invalidate()
    return $b.Text
}

# ================= DUNE: HAMBRE =================
$script:hambre = 0
$hambreTimer = New-Object System.Windows.Forms.Timer
$hambreTimer.Interval = 4000
$hambreTimer.Add_Tick({
    if ((Ocupado) -or -not $script:skin) { return }
    # la fe del culto baja sola con el tiempo
    if ($script:skin.Estilo -eq 'culto') {
        $antes = $script:fe; $script:fe = [Math]::Max(0, $script:fe - 1)
        if ($antes -ge 25 -and $script:fe -lt 25 -and -not $script:discutiendo) { Sonido 'campana'; Decir 'Cabra: La fe está bajando. Hay disidentes. Abre algo, que se nos rebelan.' }
        $form.Invalidate(); return
    }
    # a Averi le entran ganas de un sándwich de pollo
    if ($script:skin.Estilo -eq 'zorro') {
        $antes = $script:antojo; $script:antojo = [Math]::Min(100, $script:antojo + 3)
        if ($antes -lt 100 -and $script:antojo -ge 100 -and -not $script:discutiendo) { Decir '¿...huele a pollo? No huele. Pero me apetece un sándwich. (haz clic en mí)' 'serio' }
        $form.Invalidate(); return
    }
    if (-not $script:skin.Hambre) { return }
    $antes = $script:hambre
    $script:hambre = [Math]::Min(100, $script:hambre + 4)
    if ($antes -lt 100 -and $script:hambre -ge 100 -and -not $script:discutiendo) { Decir 'GRRRGH... DUNE TENER HAMBRE... (haz clic en Dune para darle de comer)' }
    $form.Invalidate()
})
function Dune-Comer {
    $script:hambre = 0; $script:salto = 10
    Decir (Azar $script:skin.Clic)
    $form.Invalidate()
}

# ================= PERSONAJES DIBUJADOS EN EL PANEL (skins nuevas) =================
# Los personajes se pintan directamente sobre el fondo, grandes y con efectos encima.
# Cada GIF se anima fotograma a fotograma con su propio ritmo.
$script:actores = [ordered]@{}; $script:actorIds = @()
$script:flotantes = New-Object System.Collections.ArrayList
$script:bmpEscena = $null
function Gif-Info($img) {
    $n = 1; $del = @(100)
    try {
        $dim = New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])
        $n = $img.GetFrameCount($dim)
        if ($n -gt 1) {
            $pi = $img.GetPropertyItem(0x5100); $del = New-Object 'int[]' $n
            for ($i = 0; $i -lt $n; $i++) { $d = [BitConverter]::ToInt32($pi.Value, $i * 4) * 10; if ($d -lt 20) { $d = 100 }; $del[$i] = $d }
        }
    } catch { $n = 1; $del = @(100) }
    return @{ N = $n; Del = $del }
}
function Nuevo-Actor($def) {
    $imgs = @{ main = (Cargar-Img $def.Gif) }
    if ($def.Extra) { foreach ($e in $def.Extra.Keys) { $imgs[$e] = Cargar-Img $def.Extra[$e] } }
    $info = @{}; foreach ($e in @($imgs.Keys)) { if ($imgs[$e]) { $info[$e] = Gif-Info $imgs[$e] } }
    # animaciones hechas con una tira de fotogramas (PNG con transparencia)
    $tiras = @{}
    if ($def.Tiras) {
        foreach ($e in $def.Tiras.Keys) {
            $tt = $def.Tiras[$e]; $fr = Cortar-Tira $tt.Archivo $tt.Frames $tt.Orden
            if ($fr) { $tiras[$e] = $fr; $imgs[$e] = $fr[0]; $del = New-Object 'int[]' $fr.Count; for ($i = 0; $i -lt $fr.Count; $i++) { $del[$i] = $tt.Delay }; $info[$e] = @{ N = $fr.Count; Del = $del } }
        }
    }
    $script:actores[$def.Id] = @{ Id = $def.Id; Imgs = $imgs; Info = $info; Pose = 'main'; Frame = 0; Acc = 0; Hasta = 0; Rect = $def.Rect
        Visible = $true; Alfa = 1.0; Flash = 0; Temblor = 0; OX = 0; OY = 0; Llenar = [bool]$def.Llenar; Base = 'main'; Tiras = $tiras; Respira = [bool]$def.Respira; Baila = [bool]$def.Baila; Dash = 0; Pixel = [bool]$def.Pixel }
    $script:actorIds += $def.Id
}
function Quitar-Actores {
    foreach ($a in @($script:actores.Values)) {
        foreach ($e in @($a.Imgs.Keys)) { if ($a.Imgs[$e] -and -not $a.Tiras.ContainsKey($e)) { $a.Imgs[$e].Dispose() } }
        foreach ($fr in @($a.Tiras.Values)) { foreach ($im in $fr) { $im.Dispose() } }
    }
    $script:actores = [ordered]@{}; $script:actorIds = @(); $script:flotantes.Clear()
}
function Cortar-Tira($ruta, $n, $orden) {
    $t = Cargar-Img $ruta; if (-not $t) { return $null }
    $w = [int]($t.Width / $n); $h = $t.Height
    if (-not $orden) { $orden = 0..($n - 1) }
    $res = New-Object System.Collections.ArrayList
    foreach ($i in $orden) {
        $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
        $g = [System.Drawing.Graphics]::FromImage($b)
        $g.DrawImage($t, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), ($i * $w), 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose(); [void]$res.Add($b)
    }
    $t.Dispose(); return ,$res.ToArray()
}
function Seleccionar-Frame($a) {
    if ($a.Tiras.ContainsKey($a.Pose)) { $a.Imgs[$a.Pose] = $a.Tiras[$a.Pose][$a.Frame]; return }
    $img = $a.Imgs[$a.Pose]; $inf = $a.Info[$a.Pose]
    if ($img -and $inf.N -gt 1) { [void]$img.SelectActiveFrame((New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])), $a.Frame) }
}
function Invalidar-Escena {
    $Z = $script:K
    $alto = if ($script:skin -and $script:skin.Alto) { [Math]::Max(200, $script:skin.Alto - 100) } else { 200 }
    # desde un poco más arriba de la escena, para que los saltos no dejen cabezas cortadas bajo la barra
    $form.Invalidate((New-Object System.Drawing.Rectangle([int](400 * $Z), [int](34 * $Z), [int](($form.ClientSize.Width / $Z - 400) * $Z), [int](($alto + 22) * $Z))))
}
function Actor-Pose($id, $pose, $ms) {
    $a = $script:actores[$id]; if (-not $a -or -not $a.Imgs[$pose]) { return }
    $a.Pose = $pose; $a.Frame = 0; $a.Acc = 0
    Seleccionar-Frame $a
    $a.Hasta = if ($ms -gt 0) { [Environment]::TickCount + $ms } else { 0 }
    Invalidar-Escena
}
function Actor-Golpe($id) { $a = $script:actores[$id]; if ($a) { $a.Flash = 6; $a.Temblor = 9 } }
# texto que sube y se desvanece (daño, balidos, corazones...)
function Flotante($txt, $x, $y, $col, $tam, $fuente) {
    [void]$script:flotantes.Add(@{ Txt = $txt; X = [double]$x; Y = [double]$y; T = 30; Col = $col; Tam = $tam; F = $(if ($fuente) { $fuente } else { 'Impact' }) })
}
function Texto-Contorno($g, $txt, $fuente, $tam, $x, $y, $color, $grosor, $alfa = 255) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, [float]$tam, (New-Object System.Drawing.PointF([float]$x, [float]$y)), [System.Drawing.StringFormat]::GenericDefault)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alfa, 0, 0, 0), [float]$grosor); $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $path); $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alfa, $color.R, $color.G, $color.B))), $path)
    $pen.Dispose(); $path.Dispose()
}
function Ancho-Texto($txt, $fuente, $tam) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, [float]$tam, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericDefault)
    $w = $path.GetBounds().Right; $path.Dispose(); return $w
}
function Pintar-Actor($g, $a) {
    if (-not $a.Visible) { return }
    $img = $a.Imgs[$a.Pose]; if (-not $img) { return }
    $r = $a.Rect
    if ($a.Llenar) {
        # rellena el recuadro recortando lo que sobra (fotos)
        $s = [Math]::Max($r[2] / $img.Width, $r[3] / $img.Height)
        $sw = $r[2] / $s; $sh = $r[3] / $s
        $src = New-Object System.Drawing.RectangleF([float](($img.Width - $sw) / 2), [float](($img.Height - $sh) / 2), [float]$sw, [float]$sh)
        $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$r[0], [float]$r[1], [float]$r[2], [float]$r[3])), $src, [System.Drawing.GraphicsUnit]::Pixel)
        return
    }
    $s = [Math]::Min($r[2] / $img.Width, $r[3] / $img.Height)
    $w = $img.Width * $s; $h = $img.Height * $s
    $x = $r[0] + ($r[2] - $w) / 2 + $a.OX; $y = $r[1] + $r[3] - $h + $a.OY
    if ($a.Flash -gt 0 -or $a.Alfa -lt 1) {
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        if ($a.Flash -gt 0) { $b = [float](0.7 * $a.Flash / 6); $cm.Matrix40 = $b; $cm.Matrix41 = $b; $cm.Matrix42 = $b }
        $cm.Matrix33 = [float]$a.Alfa
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle([int]$x, [int]$y, [int]$w, [int]$h)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $ia.Dispose()
    } else { $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h))) }
}
function Pintar-Actores($g) {
    $modo = $g.InterpolationMode; $g.InterpolationMode = 'HighQualityBilinear'
    # los personajes de pixel art (Pixel = $true) se dibujan sin suavizar, nítidos
    foreach ($a in @($script:actores.Values)) {
        if ($a.Pixel) { $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half' } else { $g.InterpolationMode = 'HighQualityBilinear'; $g.PixelOffsetMode = 'Default' }
        Pintar-Actor $g $a
    }
    $g.InterpolationMode = $modo; $g.PixelOffsetMode = 'Default'
}
function Pintar-Flotantes($g) {
    foreach ($f in $script:flotantes) {
        $alfa = [int][Math]::Min(255, $f.T * 22)
        if ($f.Txt -eq '<3') { Dibujar-Corazon $g $f.X $f.Y $f.Tam $alfa }
        else { Texto-Contorno $g $f.Txt $f.F $f.Tam $f.X $f.Y $f.Col ([Math]::Max(3, $f.Tam / 5)) $alfa }
    }
}
# hace que la Cara/Cara2 de siempre muevan a los personajes dibujados
function Cara2($clave, $ms) { if ($script:actorIds.Count -ge 2) { Actor-Pose $script:actorIds[1] $clave $ms } }
$actTimer = New-Object System.Windows.Forms.Timer
$actTimer.Interval = 40
$script:ultimoTick = [Environment]::TickCount
$actTimer.Add_Tick({
    Sin-Destellos
    $ahora = [Environment]::TickCount; $dt = $ahora - $script:ultimoTick; $script:ultimoTick = $ahora
    if ($dt -gt 200) { $dt = 200 }
    if ($script:actores.Count -eq 0) { return }
    $cambio = $false
    foreach ($a in @($script:actores.Values)) {
        if ($a.Hasta -gt 0 -and $ahora -ge $a.Hasta) { $a.Hasta = 0; $a.Pose = $a.Base; $a.Frame = 0; $a.Acc = 0; Seleccionar-Frame $a; $cambio = $true }
        $inf = $a.Info[$a.Pose]
        if ($inf -and $inf.N -gt 1 -and $a.Visible) {
            $a.Acc += $dt; $avanza = $false
            while ($a.Acc -ge $inf.Del[$a.Frame]) { $a.Acc -= $inf.Del[$a.Frame]; $a.Frame = ($a.Frame + 1) % $inf.N; $avanza = $true }
            if ($avanza) { Seleccionar-Frame $a; $cambio = $true }
        }
        if ($a.Flash -gt 0) { $a.Flash--; $cambio = $true }
        if ($a.Temblor -gt 0) { $a.Temblor--; $a.OX = $Rnd.Next(-5, 6) * [Math]::Min(1, $a.Temblor); $a.OY = $Rnd.Next(-3, 4) * [Math]::Min(1, $a.Temblor); $cambio = $true }
        elseif ($a.Dash -gt 0) { $a.Dash--; $a.OX = - [Math]::Sin(($a.Dash / 14.0) * [Math]::PI) * 80; $cambio = $true }
        elseif ($a.Salto -gt 0) { $a.Salto--; $a.OX = 0; $a.OY = - [Math]::Sin(($a.Salto / 12.0) * [Math]::PI) * 24; $cambio = $true }
        elseif ($a.Baila) { $tb = $ahora / 1000.0; $a.OY = - [Math]::Abs([Math]::Sin($tb * 3.4)) * 8; $a.OX = [Math]::Sin($tb * 1.7) * 6; $cambio = $true }
        elseif ($a.Respira) { $a.OY = [Math]::Sin($ahora / 650.0) * 3; $a.OX = [Math]::Sin($ahora / 1700.0) * 2; $cambio = $true }
    }
    if ($script:flotantes.Count -gt 0) {
        for ($i = $script:flotantes.Count - 1; $i -ge 0; $i--) { $f = $script:flotantes[$i]; $f.T--; $f.Y -= 1.3; if ($f.T -le 0) { $script:flotantes.RemoveAt($i) } }
        $cambio = $true
    }
    if ($cambio) { Invalidar-Escena }
})
$script:fuentes = $null
function Existe-Fuente($n) {
    if (-not $script:fuentes) { $script:fuentes = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }) }
    return ($script:fuentes -contains $n)
}

# ================= CORDERO Y CABRA: FE DEL CULTO Y RITUALES =================
$script:fe = 60; $script:seguidores = 0; $script:ritualFx = 0
function Cordero-Clic {
    Sonido 'balido'; Cara 'clic' 1800
    Flotante '¡BEEE!' 470 70 (C 255 250 240) 22 'Palatino Linotype'
    $script:fe = [Math]::Min(100, $script:fe + 2)
    Decir (Azar $script:skin.Clic); $form.Invalidate()
}
function Cabra-Clic {
    if ($Rnd.Next(2) -eq 0) {
        Sonido 'grito'; Cara2 'grito' 2400; Actor-Golpe 'G'
        Flotante '¡AAAAH!' 616 70 (C 190 130 240) 24 'Palatino Linotype'
    } else {
        Sonido 'risa'; Cara2 'risa' 2800
        Flotante 'JA JA JA' 620 74 (C 190 130 240) 18 'Palatino Linotype'
    }
    Decir (Azar $script:skin.Clic2)
}
# cada 5 apps abiertas: ritual con tentáculos
function Culto-Ritual {
    $script:ritualFx = 44; $script:fe = [Math]::Min(100, $script:fe + 20)
    Sonido 'ritual'; Cara 'baile' 3200; Cara2 'risa' 3200
    Flotante '¡RITUAL!' 520 90 (C 255 70 80) 34 'Palatino Linotype'
    Decir "¡RITUAL! $($script:seguidores) seguidores. Cabra: *Salen tentáculos del suelo.* La fe sube. Y el miedo."
    $form.Invalidate()
}
# la Cabra habla con sus voces reales del juego; el Cordero bala
function Voz-Culto($texto) {
    if ($texto -match '^Cabra:') { if ($texto -match '¡|!') { Sonido 'enfado' } else { Sonido 'voz' } }
    elseif ($texto -match '^Cordero:' -and $Rnd.Next(2) -eq 0) { Sonido 'balido' }
}

# ================= PYROPHINA Y ZARATANA: PELEA DE KAIJUS =================
$script:kHP = @{ P = 1000; Z = 1000 }; $script:kFase = @{ P = $false; Z = $false }; $script:kFin = $false; $script:kGanadora = ''
$script:collares = @{ P = 0; Z = 0 }
$script:particulas = New-Object System.Collections.ArrayList
$kRevTimer = New-Object System.Windows.Forms.Timer
$kRevTimer.Interval = 7000
$kRevTimer.Add_Tick({
    $kRevTimer.Stop()
    if ($script:skin.Estilo -ne 'kaiju') { return }
    Kaiju-Reiniciar
    Sonido 'intro'
    Decir 'WMEW 99.9: Steven las ha vuelto a invocar. ¡Segundo asalto!'
    $form.Invalidate()
})
function Kaiju-Reiniciar {
    $script:kHP = @{ P = 1000; Z = 1000 }; $script:kFase = @{ P = $false; Z = $false }; $script:kFin = $false; $script:kGanadora = ''
    $script:particulas.Clear()
    foreach ($a in @($script:actores.Values)) { $a.Visible = $true; $a.Alfa = 1.0 }
    Invalidar-Escena
}
function Centro-Kaiju($id) { $a = $script:actores[$id]; if (-not $a) { return @(500, 150) }; return @(($a.Rect[0] + $a.Rect[2] / 2), ($a.Rect[1] + $a.Rect[3] * 0.45)) }
# una kaiju ataca a la otra ('P' = Pyrophina, 'Z' = Zaratana). Con 500 o menos entran en su fase 2, como en el juego.
function Kaiju-Ataque($q, $texto) {
    if (Ocupado) { return }
    if ($script:kFin) { Decir 'WMEW 99.9: La pelea ha terminado. Steven las está volviendo a invocar...'; return }
    $obj = if ($q -eq 'P') { 'Z' } else { 'P' }
    $dmg = $Rnd.Next(45, 111); if ($script:kFase[$q]) { $dmg += 30 }
    $co = Centro-Kaiju $obj; $ca = Centro-Kaiju $q
    if ($q -eq 'P') {
        if ($Rnd.Next(3) -eq 0) {
            Cara 'fuego' 2600; Sonido 'pfuego'; $msg = "Pyrophina: ¡AAARGH! *Aliento de fuego.* Zaratana pierde $dmg."
            # chorro de fuego desde la boca de Pyrophina hasta Zaratana
            for ($i = 0; $i -lt 34; $i++) { $t = $Rnd.NextDouble(); [void]$script:particulas.Add(@{ T = 'f'; D = $i; X = [double]($ca[0] + 40); Y = [double]($ca[1] - 30); VX = ($co[0] - $ca[0] - 40) / 14.0 + ($Rnd.NextDouble() - 0.5) * 2; VY = ($co[1] - $ca[1] + 30) / 14.0 + ($Rnd.NextDouble() - 0.5) * 3; V = 16 }) }
        }
        else { Cara 'ataque' 1800; Sonido 'pataque'; $msg = "Pyrophina: *Zarpazo y lanzamiento.* Zaratana pierde $dmg." }
    } else {
        if ($Rnd.Next(3) -eq 0) {
            Cara2 'meteoros' 2600; Sonido 'zmeteoros'; $msg = "Zaratana: *Bombardeo de meteoritos.* Pyrophina pierde $dmg."
            # meteoritos que caen sobre Pyrophina
            for ($i = 0; $i -lt 6; $i++) { $tx = $co[0] + $Rnd.Next(-50, 51); [void]$script:particulas.Add(@{ T = 'm'; D = $i * 4; X = [double]($tx - 90); Y = -20.0; VX = 5.0; VY = 9.0; V = [int](($co[1] + 40) / 9) }) }
        }
        else { Cara2 'ataque' 1500; Sonido 'zataque'; $msg = "Zaratana: ¡GRRRR, GRRRRR! *Embestida.* Pyrophina pierde $dmg." }
    }
    if ($texto) { $msg = "$texto (-$dmg)" }
    $script:kHP[$obj] = $script:kHP[$obj] - $dmg
    Actor-Golpe $obj
    Flotante "-$dmg" ($co[0] - 18) ($co[1] - 70) $(if ($q -eq 'P') { (C 255 150 40) } else { (C 200 190 255) }) 30 'EdmundMcMillen_INTLv4'
    Sacudir $form 6
    if ($script:kHP[$obj] -le 0) {
        $script:kHP[$obj] = 0; $script:kFin = $true; $script:kGanadora = $q; $script:collares[$q]++
        $script:particulas.Clear()
        $perd = $script:actores[$obj]; if ($perd) { $perd.Alfa = 0.25; $perd.Hasta = 0; $perd.Pose = 'main' }
        Flotante 'K.O.' ($co[0] - 30) ($co[1] - 40) (C 255 60 50) 40 'EdmundMcMillen_INTLv4'
        if ($q -eq 'P') { Cara 'gana' 6500; Sonido 'pgana'; $msg = 'WMEW 99.9: ¡PYROPHINA GANA! Te da las gracias... y su collar.' }
        else { Cara2 'gana' 6500; Sonido 'zgana'; $msg = 'WMEW 99.9: ¡ZARATANA GANA! Te da las gracias... y su collar.' }
        $kRevTimer.Stop(); $kRevTimer.Start()
    } elseif (-not $script:kFase[$obj] -and $script:kHP[$obj] -le 500) {
        $script:kFase[$obj] = $true
        if ($obj -eq 'P') { Sonido 'pruge'; $msg = 'WMEW 99.9: ¡Pyrophina está a media vida! ¡Desata la TORMENTA DE FUEGO!' }
        else { Sonido 'zruge'; $msg = 'WMEW 99.9: ¡Zaratana está a media vida! ¡Desata el METEORNADO!' }
    }
    Decir $msg
    $form.Invalidate()
}
# brasas (tormenta de fuego) y meteoritos (meteornado) en el fondo
function Kaiju-Particulas {
    $Z = $script:K; $W = [Math]::Max(700, $form.ClientSize.Width / $Z)
    # tormenta de fuego (brasas) y meteornado (meteoritos) mientras dure la fase 2
    if (-not $script:kFin) {
        if ($script:kFase.P -and $Rnd.Next(2) -eq 0) { [void]$script:particulas.Add(@{ T = 'b'; D = 0; X = [double]$Rnd.Next(380, [int]$W); Y = 250.0; VX = ($Rnd.NextDouble() - 0.5) * 2; VY = -1.5 - $Rnd.NextDouble() * 2.5; V = 60 }) }
        if ($script:kFase.Z -and $Rnd.Next(9) -eq 0) { [void]$script:particulas.Add(@{ T = 'm'; D = 0; X = [double]$Rnd.Next(300, [int]$W - 60); Y = -20.0; VX = 4.0; VY = 7.0; V = 40 }) }
    }
    if ($script:particulas.Count -gt 0) {
        for ($i = $script:particulas.Count - 1; $i -ge 0; $i--) {
            $p = $script:particulas[$i]
            if ($p.D -gt 0) { $p.D--; continue }
            $p.X += $p.VX; $p.Y += $p.VY; $p.V--
            if ($p.V -le 0 -or $p.Y -gt 330) {
                if ($p.T -eq 'm' -and $p.Y -gt 60 -and $p.Y -lt 260) { Sonido 'zmeteoro'; for ($j = 0; $j -lt 5; $j++) { [void]$script:particulas.Add(@{ T = 'p'; D = 0; X = $p.X; Y = $p.Y; VX = ($Rnd.NextDouble() - 0.5) * 6; VY = -$Rnd.NextDouble() * 4; V = 10 }) } }
                $script:particulas.RemoveAt($i)
            }
        }
        Invalidar-Escena
    }
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](200 * $Z), [int](30 * $Z))))
}
function Pintar-Particulas($g) {
    foreach ($p in $script:particulas) {
        if ($p.D -gt 0) { continue }
        switch ($p.T) {
            'b' { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $p.V * 5), 255, (110 + ($p.V % 4) * 30), 30))), [float]$p.X, [float]$p.Y, 4, 4) }
            'f' {
                $s = 8 + (16 - $p.V) * 2.2; $al = [Math]::Max(0, [Math]::Min(230, $p.V * 16))
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 255, 90, 20))), [float]($p.X - $s / 2), [float]($p.Y - $s / 2), [float]$s, [float]$s)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 255, 230, 120))), [float]($p.X - $s / 4), [float]($p.Y - $s / 4), [float]($s / 2), [float]($s / 2))
            }
            'm' {
                $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 255, 170, 80), 4)), [float]($p.X - $p.VX * 5), [float]($p.Y - $p.VY * 5), [float]$p.X, [float]$p.Y)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 120 112 124))), [float]($p.X - 7), [float]($p.Y - 7), 15, 15)
                $g.DrawEllipse((New-Object System.Drawing.Pen((C 40 36 44), 2)), [float]($p.X - 7), [float]($p.Y - 7), 15, 15)
            }
            'p' { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $p.V * 25), 150, 140, 150))), [float]$p.X, [float]$p.Y, 6, 6) }
        }
    }
}
# barra de vida de jefe con nombre, al estilo de Mewgenics
function Vida-Kaiju($g, $nombre, $hp, $x, $y, $w, $col, $fase2) {
    $placa = Ruta-Redonda ($x - 2) ($y - 2) ($w + 4) 22 10
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 22, 14, 16))), $placa)
    $g.DrawPath((New-Object System.Drawing.Pen((C 20 10 10), 2.5)), $placa); $placa.Dispose()
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 22 22))), ($x + 3), ($y + 3), ($w - 6), 14)
    $c = if ($fase2) { [System.Drawing.Color]::FromArgb(255, [Math]::Min(255, $col.R + 30), [Math]::Min(255, $col.G + 50), [Math]::Min(255, $col.B + 20)) } else { $col }
    $ancho = [int](($w - 6) * [Math]::Max(0, $hp) / 1000)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), ($x + 3), ($y + 3), $ancho, 14)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))), ($x + 3), ($y + 3), $ancho, 5)
    $txt = if ($hp -le 0) { "$nombre  K.O." } elseif ($fase2) { "¡$nombre!  $hp" } else { "$nombre  $hp" }
    Texto-Contorno $g $txt 'EdmundMcMillen_INTLv4' 13 ($x + 6) ($y + 1) (C 255 250 235) 3
}

# ================= AVERI: ANTOJO DE SÁNDWICH Y CORAZONES =================
$script:antojo = 0
function Nuevo-Corazon {
    $a = $script:actores['A']; if (-not $a) { return }
    $r = $a.Rect
    Flotante '<3' ($r[0] + $Rnd.Next(20, $r[2] - 20)) ($r[1] + $r[3] - $Rnd.Next(10, 50)) $null $Rnd.Next(9, 15)
}
function Dibujar-Corazon($g, $x, $y, $s, $alfa) {
    $x = [float]$x; $y = [float]$y; $s = [float]$s
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier($x, ($y + $s * 0.3), $x, ($y - $s * 0.3), ($x - $s * 1.1), ($y - $s * 0.3), ($x - $s * 1.1), ($y + $s * 0.35))
    $p.AddBezier(($x - $s * 1.1), ($y + $s * 0.35), ($x - $s * 1.1), ($y + $s * 0.8), ($x - $s * 0.3), ($y + $s * 1.0), $x, ($y + $s * 1.35))
    $p.AddBezier($x, ($y + $s * 1.35), ($x + $s * 0.3), ($y + $s * 1.0), ($x + $s * 1.1), ($y + $s * 0.8), ($x + $s * 1.1), ($y + $s * 0.35))
    $p.AddBezier(($x + $s * 1.1), ($y + $s * 0.35), ($x + $s * 1.1), ($y - $s * 0.3), $x, ($y - $s * 0.3), $x, ($y + $s * 0.3))
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alfa, 240, 80, 110))), $p)
    $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alfa, 120, 30, 50), 1.5)), $p)
    $p.Dispose()
}
function Dibujar-Sandwich($g, $x, $y, $s) {
    $w = 32 * $s; $l = $x - $w / 2
    $lin = New-Object System.Drawing.Pen((C 110 60 30), [float](1.5 * $s))
    $pan = New-Object System.Drawing.SolidBrush((C 238 196 120))
    $r = Ruta-Redonda $l ($y + 14 * $s) $w (6 * $s) (4 * $s); $g.FillPath($pan, $r); $g.DrawPath($lin, $r); $r.Dispose()
    $r = Ruta-Redonda ($l + 1 * $s) ($y + 9 * $s) ($w - 2 * $s) (6 * $s) (4 * $s); $g.FillPath((New-Object System.Drawing.SolidBrush((C 214 140 80))), $r); $g.DrawPath($lin, $r); $r.Dispose()
    $pts = for ($i = 0; $i -le 8; $i++) { New-Object System.Drawing.PointF([float]($l + $i * $w / 8), [float]($y + 8 * $s + (($i % 2) * 3 - 1.5) * $s)) }
    $g.DrawLines((New-Object System.Drawing.Pen((C 110 180 70), [float](3 * $s))), [System.Drawing.PointF[]]$pts)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddArc([float]$l, [float]($y - 4 * $s), [float]$w, [float](22 * $s), 180, 180); $p.CloseFigure()
    $g.FillPath($pan, $p); $g.DrawPath($lin, $p); $p.Dispose()
    foreach ($sx in @(0.3, 0.5, 0.7)) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 245 220))), [float]($l + $w * $sx - 1.5 * $s), [float]$y, [float](3 * $s), [float](2 * $s)) }
    $lin.Dispose(); $pan.Dispose()
}
function Averi-Clic {
    $k = $script:skin
    if ($script:antojo -ge 40) {
        $script:antojo = 0; Sonido 'comer'
        for ($i = 0; $i -lt 4; $i++) { Nuevo-Corazon }
        Decir (Azar $k.Comer) 'abiertos'
    } else {
        Sonido 'yip'; Nuevo-Corazon
        Decir (Azar $k.Clic) (@('cerrados', 'abiertos')[$Rnd.Next(2)])
    }
    $form.Invalidate()
}

# ================= SEBASTIAN SOLACE: SU TIENDA =================
# Abrir programas da "investigación"; en la tienda se cambia por objetos reales de Pressure.
$script:modoTienda = $false; $script:investigacion = 10; $script:inventario = New-Object System.Collections.ArrayList
$script:visitas = 0; $script:comprasVisita = 0; $script:toques = 0; $script:iconosTienda = @{}
$script:enfadoFx = 0; $script:destello = 0
$visitasTimer = New-Object System.Windows.Forms.Timer
$visitasTimer.Interval = 90000
$visitasTimer.Add_Tick({ $visitasTimer.Stop(); $script:visitas = 0 })
function Icono-Tienda($it) {
    if (-not $it.Img) { return $null }
    if (-not $script:iconosTienda.ContainsKey($it.Id)) { $script:iconosTienda[$it.Id] = Cargar-Img $it.Img }
    return $script:iconosTienda[$it.Id]
}
function Dibujar-Objeto($g, $id, $x, $y, $s) {
    $it = @($script:skin.Tienda | Where-Object { $_.Id -eq $id })[0]
    $ic = if ($it) { Icono-Tienda $it } else { $null }
    if ($ic) { $g.DrawImage($ic, [float]$x, [float]$y, [float]$s, [float]$s); return }
    # Flash Beacon: no hay dibujo en la wiki, así que es un faro amarillo
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 220 80))), [float]($x + $s * 0.2), [float]($y + $s * 0.15), [float]($s * 0.6), [float]($s * 0.6))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 64 70))), [float]($x + $s * 0.3), [float]($y + $s * 0.62), [float]($s * 0.4), [float]($s * 0.3))
}
function Sebastian-Clic {
    if ($script:modoTienda) {
        # tocarle dentro de la tienda: se enfada cada vez más
        $k = $script:skin; $script:toques++
        Actor-Golpe 'S'
        if ($script:toques -ge 7) { Sebastian-Enfado 'Te lo advertí...'; $script:toques = 0 }
        else { Decir $k.Tocar[[Math]::Min($script:toques - 1, $k.Tocar.Count - 1)] }
        return
    }
    Tienda-Entrar
}
function Tienda-Entrar {
    $k = $script:skin
    $script:visitas++; $script:comprasVisita = 0; $script:toques = 0
    $visitasTimer.Stop(); $visitasTimer.Start()
    $script:modoTienda = $true; $script:modoSkins = $false
    if ($script:visitas -ge 4) { Sebastian-Enfado (Azar $k.Entrar3); $script:visitas = 2 }
    elseif ($script:visitas -ge 2) { Decir (Azar $k.Entrar2) }
    else { Decir (Azar $k.Entrar) }
    Mostrar-Pagina; $form.Invalidate()
}
function Tienda-Salir {
    $k = $script:skin; $script:modoTienda = $false
    if ($script:comprasVisita -eq 0) { Decir (Azar $k.SalirSinComprar) } else { Decir (Azar $k.Salir) }
    Mostrar-Pagina; $form.Invalidate()
}
function Tienda-Comprar($it) {
    $k = $script:skin
    if ($script:investigacion -lt $it.Precio) { Decir (Azar $k.Pobre); Actor-Golpe 'S'; return }
    $script:investigacion -= $it.Precio; $script:comprasVisita++
    [void]$script:inventario.Add($it.Id); while ($script:inventario.Count -gt 5) { $script:inventario.RemoveAt(0) }
    Sonido 'compra'
    Flotante "-$($it.Precio)" 150 262 (C 255 190 70) 22 'Bahnschrift'
    if ($it.Id -eq 'flash') {
        # le enciende el Flash Beacon en la cara
        Sonido 'flash'; $script:destello = 12; Actor-Golpe 'S'; Sacudir $form 8
        Decir (Azar @('¡¡GAAAAAAAH!!', '*GEURH* ...No. Lo. Vuelvas. A. Hacer.'))
    }
    elseif ($it.Id -eq 'pilas') { Decir (Azar $k.ComprarPilas) }
    elseif ($it.Escaso) { Decir (Azar $k.ComprarEscaso) }
    else { Decir (Azar $k.Comprar) }
    $form.Invalidate()
}
function Sebastian-Enfado($texto) {
    $script:enfadoFx = 26; Actor-Golpe 'S'; Sacudir $form 14
    Flotante 'GET. OUT!' 480 90 (C 255 40 40) 42 'Bahnschrift'
    Decir $texto
}

# ================= PURSUER: LA CAZA =================
$script:presas = 0; $script:estamina = 110.0; $script:acechando = $false
$script:zarpas = New-Object System.Collections.ArrayList; $script:ondas = New-Object System.Collections.ArrayList; $script:gotas = New-Object System.Collections.ArrayList
$script:rojoFx = 0
$acechoTimer = New-Object System.Windows.Forms.Timer
$acechoTimer.Interval = 5000
$acechoTimer.Add_Tick({ $acechoTimer.Stop(); if ($script:skin.Estilo -eq 'dod' -and $script:acechando) { Pursuer-Desacecho } })
function Pursuer-Zarpas($n) { for ($i = 0; $i -lt $n; $i++) { [void]$script:zarpas.Add(@{ X = [double]$Rnd.Next(430, 700); Y = [double]$Rnd.Next(80, 200); A = $Rnd.Next(-35, 35); T = 32 }) } }
function Pursuer-Sangre($n) { for ($i = 0; $i -lt $n; $i++) { [void]$script:gotas.Add(@{ X = [double]$Rnd.Next(450, 700); Y = [double]$Rnd.Next(90, 190); VX = ($Rnd.NextDouble() - 0.5) * 4; VY = -$Rnd.NextDouble() * 4; T = 30 }) } }
function Pursuer-Ataque($tipo, $texto) {
    if (Ocupado) { return }
    if ($script:acechando) { Pursuer-Desacecho; return }
    if ($script:estamina -lt 20 -and $tipo -ne 'presa') { Decir '*Jadea. Necesita recuperar el aliento.*'; return }
    $a = $script:actores['P']
    switch ($tipo) {
        'zarpazo' {
            $script:estamina -= 15; Sonido 'zarpazo'; Pursuer-Zarpas 1; if ($a) { $a.Dash = 10 }
            Decir $(if ($texto) { $texto } else { '*Zarpazo.* Sus garras cortan como cuchillas.' })
        }
        'espada' {
            $script:estamina -= 30; Sonido 'espada'; Sonido 'corte'; Pursuer-Zarpas 3; Pursuer-Sangre 10; $script:rojoFx = 8; if ($a) { $a.Dash = 14 }
            Decir $(if ($texto) { $texto } else { '*Desenvaina la espada negra.* ¡CORTE! *La herida sangra.*' })
        }
        'aullido' {
            $script:estamina -= 25; Sonido 'aullido'; Sonido 'onda'
            [void]$script:ondas.Add(@{ R = 10.0; T = 34 }); Sacudir $form 16
            Decir $(if ($texto) { $texto } else { '*AÚLLA.* Nada se atreve a responder a su llamada.' })
        }
        'presa' {
            $script:presas++; Sonido 'corte'; Pursuer-Zarpas 2; Pursuer-Sangre 6
            Flotante '+1 PRESA' 470 100 (C 255 52 41) 26 'Arial Black'
            Decir $texto
        }
    }
    $script:estamina = [Math]::Max(0, $script:estamina)
    $form.Invalidate()
}
function Pursuer-Acecho {
    if ($script:acechando -or (Ocupado)) { return }
    $script:acechando = $true
    $a = $script:actores['P']; if ($a) { $a.Alfa = 0.06 }
    Sonido 'acecho'; Decir '...te veo. *Desaparece entre los árboles.*'
    $acechoTimer.Stop(); $acechoTimer.Interval = $Rnd.Next(3500, 7000); $acechoTimer.Start()
    Invalidar-Escena
}
function Pursuer-Desacecho {
    $script:acechando = $false; $acechoTimer.Stop()
    $a = $script:actores['P']; if ($a) { $a.Alfa = 1.0; $a.Dash = 14 }
    Sonido 'zarpazo'; Sonido 'corte'; Pursuer-Zarpas 3; Pursuer-Sangre 12; $script:rojoFx = 10; Sacudir $form 10
    Flotante '¡CARNE FRESCA!' 440 90 (C 255 52 41) 32 'Arial Black'
    Decir '¡AHH, CARNE FRESCA!'
}
function Pursuer-Clic { Pursuer-Ataque (Azar @('zarpazo', 'zarpazo', 'espada', 'aullido')) }
# animación de efectos de Pursuer y Sebastian (la llama el temporizador del fondo)
function Efectos-Caza {
    $hay = $false
    for ($i = $script:zarpas.Count - 1; $i -ge 0; $i--) { $script:zarpas[$i].T--; $hay = $true; if ($script:zarpas[$i].T -le 0) { $script:zarpas.RemoveAt($i) } }
    for ($i = $script:ondas.Count - 1; $i -ge 0; $i--) { $o = $script:ondas[$i]; $o.T--; $o.R += 11; $hay = $true; if ($o.T -le 0) { $script:ondas.RemoveAt($i) } }
    for ($i = $script:gotas.Count - 1; $i -ge 0; $i--) { $o = $script:gotas[$i]; $o.T--; $o.X += $o.VX; $o.Y += $o.VY; $o.VY += 0.6; $hay = $true; if ($o.T -le 0) { $script:gotas.RemoveAt($i) } }
    if ($script:rojoFx -gt 0) { $script:rojoFx--; $hay = $true }
    if ($script:enfadoFx -gt 0) { $script:enfadoFx--; $hay = $true }
    if ($script:destello -gt 0) { $script:destello--; $hay = $true }
    if ($script:estamina -lt 110) { $script:estamina = [Math]::Min(110.0, $script:estamina + 0.3); $hay = $true }
    if ($script:acechando) { $hay = $true }
    if ($hay) { Invalidar-Escena; $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](268 * $script:K), [int](400 * $script:K), [int](40 * $script:K)))) }
}

# ================= KASANE TETO: PAJARITOS (BIRDBRAIN) =================
# Cada app que abres atrae a un pajarito. Al quinto, uno se le posa en la cabeza: ¡BIRDBRAIN!
$script:pajaros = New-Object System.Collections.ArrayList
$script:birdbrains = 0
# sitios donde se posan: encima de las fotos y en el suelo
$script:posaderos = @(@(462, 70), @(500, 70), @(492, 170), @(530, 172), @(448, 290), @(520, 290))
function Teto-Cabeza {
    $a = $script:actores['T']; $oy = if ($a) { $a.OY } else { 0 }
    $ox = if ($a) { $a.OX } else { 0 }
    return @((643 + $ox), (90 + $oy))
}
function Pajaros-Vivos { return @($script:pajaros | Where-Object { $_.Est -ne 'huye' }).Count }
function Teto-Pajaro {
    $n = Pajaros-Vivos
    if ($n -ge 5) { return }
    $lado = if ($Rnd.Next(2) -eq 0) { 1 } else { -1 }
    $sx = if ($lado -eq 1) { 400 } else { 760 }
    if ($n -eq 4) { $t = Teto-Cabeza; $cab = $true }
    else {
        $usados = @($script:pajaros | Where-Object { $_.Est -ne 'huye' } | ForEach-Object { $_.P })
        $libres = @(0..($script:posaderos.Count - 1) | Where-Object { $usados -notcontains $_ })
        $pi = $libres[$Rnd.Next($libres.Count)]; $t = $script:posaderos[$pi]; $cab = $false
    }
    [void]$script:pajaros.Add(@{ X = [double]$sx; Y = [double]$Rnd.Next(60, 120); TX = [double]$t[0]; TY = [double]$t[1]; Est = 'vuela'; Dir = $lado; F = $Rnd.NextDouble() * 6; P = $(if ($cab) { -1 } else { $pi }); Cab = $cab })
    Sonido 'pio'
}
function Teto-Birdbrain {
    $script:birdbrains++
    Sonido 'birdbrain'; $script:tetoVozT = [Environment]::TickCount
    Flotante 'BIRDBRAIN!' 444 110 (C 255 214 60) 34 'Arial Black'
    $a = $script:actores['T']; if ($a) { $a.Salto = 12 }
    Decir-Fijo (Azar @('¡Un pajarito en la cabeza! Ahora sí que tengo cerebro de pájaro. ¡BIRDBRAIN!', '¡Hiii~! ...¿por qué me miráis todos? ¿Tengo algo en el pelo?', '¡Cinco pajaritos! Uno se ha quedado a vivir aquí arriba. Se llama Pan.'))
    $form.Invalidate()
}
$script:tetoVozT = 0; $script:tetoClics = New-Object System.Collections.ArrayList; $script:tetoArrastre = 0
# elige el audio según lo que dice (la primera palabra clave que encuentre)
$TetoPalabras = @(
    ,@('buenos días|good morning', 'morning'), ,@('buenas noches|good night|a dormir', 'goodnight'), ,@('birdbrain|cerebro de pájaro', 'birdbrain')
    ,@('hiii|hi hi', 'hola'), ,@('baguette|\bpan\b', 'baguette'), ,@('♪|canta|tararea|la la', 'canta'), ,@('pajarit|pájaro|\bpío', 'tweet')
    ,@('bye|adiós|hasta luego|nos vemos', 'seeya'), ,@('oh,? no', 'ohno'), ,@('¡ay[!,]', 'ow'), ,@('perdón|lo siento', 'sorry'), ,@('\bups\b|\buy\b', 'oops2')
    ,@('espera', 'wait'), ,@('¿qué\?|¿eh\?', 'what'), ,@('\bhola\b|\bhey\b|\boye\b', 'hey'), ,@('vamos|let''s go', 'letsgo'), ,@('¡sí|\bsí[,!.]', 'yes')
    ,@('no, no|¡no!', 'nonono'), ,@('\bric[oa]\b|ñam', 'yummy'), ,@('\bmon[oa]\b|guap|adorable', 'cute'), ,@('\bwow\b|\bhala\b', 'wow')
    ,@('yupi|genial|ta-chán|yay', 'alegre'), ,@('feliz|content[oa]', 'happy'), ,@('\bteto\b', 'teto'), ,@('okay|\bvale\b', 'okay'), ,@('\?', 'huh')
)
function Voz-Teto($txt) {
    $ahora = [Environment]::TickCount
    if (($ahora - $script:tetoVozT) -lt 1500 -or ($ahora - $script:ultimoSonido) -lt 600) { return }
    $clave = $null
    foreach ($p in $TetoPalabras) { if ($txt -match $p[0]) { $clave = $p[1]; break } }
    if (-not $clave) { if ($Rnd.Next(2) -eq 0) { $clave = Azar @('hehe', 'hi', 'hey') } else { return } }
    $script:tetoVozT = $ahora
    Sonido-De 'Kasane Teto' $clave
}
function Teto-Clic {
    $a = $script:actores['T']; if ($a) { $a.Salto = 12 }
    $ahora = [Environment]::TickCount; [void]$script:tetoClics.Add($ahora)
    while ($script:tetoClics.Count -gt 0 -and ($ahora - $script:tetoClics[0]) -gt 2500) { $script:tetoClics.RemoveAt(0) }
    if ($script:tetoClics.Count -ge 4) {
        $script:tetoClics.Clear(); Sonido 'ow'; $script:tetoVozT = $ahora
        Flotante '@_@' 600 80 (C 214 40 64) 26 'Arial Black'
        Decir (Azar @('¡Ay! ¡Que me mareo de tanto saltar! *Da vueltas como una peonza.*', '¡Ay, ay! ¡Para! Veo pajaritos. ...ah, no, son los de siempre.'))
        $form.Invalidate(); return
    }
    foreach ($i in 0..2) { Flotante '♪' (580 + $i * 40) (90 + $Rnd.Next(30)) (@((C 214 40 64), (C 246 170 30), (C 255 255 255))[$i]) 22 'Segoe UI Symbol' }
    if ((Pajaros-Vivos) -gt 0) {
        # al saltar, los pájaros salen volando
        foreach ($b in $script:pajaros) { if ($b.Est -ne 'huye') { $b.Est = 'huye'; $b.Dir = $(if ($b.X -lt 600) { -1 } else { 1 }) } }
        Sonido 'pio'; Sonido 'byebye'
        Decir (Azar @('¡Bye-bye, pajaritos! ...¡ay, no, volved!', '¡Hiii! *Los pájaros salen volando.* Bueno, ya volverán. Siempre vuelven.', '*Salta de alegría y espanta a todos los pájaros.* ¡Ups!'))
    } else {
        $v = Azar $script:skin.Voces
        Sonido $v[1]; Decir $v[0]
    }
    $form.Invalidate()
}
function Teto-Tick {
    if ($script:pajaros.Count -eq 0) { return }
    for ($i = $script:pajaros.Count - 1; $i -ge 0; $i--) {
        $b = $script:pajaros[$i]; $b.F += 0.9
        switch ($b.Est) {
            'vuela' {
                if ($b.Cab) { $t = Teto-Cabeza; $b.TX = $t[0]; $b.TY = $t[1] }
                $dx = $b.TX - $b.X; $dy = $b.TY - $b.Y; $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
                if ($d -lt 8) { $b.X = $b.TX; $b.Y = $b.TY; if ($b.Cab) { $b.Est = 'cabeza'; Teto-Birdbrain } else { $b.Est = 'posado'; if ($Rnd.Next(3) -eq 0) { Sonido 'tweet'; $script:tetoVozT = [Environment]::TickCount } } }
                else { $v = [Math]::Min(9, $d); $b.X += $dx / $d * $v; $b.Y += $dy / $d * $v - [Math]::Sin($b.F) * 1.2; $b.Dir = $(if ($dx -ge 0) { 1 } else { -1 }) }
            }
            'cabeza' { $t = Teto-Cabeza; $b.X = $t[0]; $b.Y = $t[1] }
            'huye' { $b.X += $b.Dir * 12; $b.Y -= 3; if ($b.Y -lt 68 -or $b.X -lt 410 -or $b.X -gt 738) { $script:pajaros.RemoveAt($i) } }
        }
    }
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](290 * $script:K), [int](400 * $script:K), [int](46 * $script:K))))
}
# paloma dibujada: cuerpo gris, cuello brillante, pico naranja; aletea si vuela
function Dibujar-Pajaro($g, $x, $y, $esc, $vuela, $fase, $dir) {
    $st = $g.Save()
    $g.TranslateTransform([float]$x, [float]$y); $g.ScaleTransform([float]($esc * $dir), [float]$esc)
    $gris = New-Object System.Drawing.SolidBrush((C 150 160 178)); $oscuro = New-Object System.Drawing.SolidBrush((C 104 112 132))
    $g.FillPolygon($oscuro, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(-9, -5)), (New-Object System.Drawing.PointF(-17, -8)), (New-Object System.Drawing.PointF(-16, -1))))
    $g.FillEllipse($gris, -11, -10, 21, 12)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 110 176 160))), 4, -11, 7, 6)
    $g.FillEllipse($oscuro, 6, -17, 10, 9)
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 240 150 40))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(15, -14)), (New-Object System.Drawing.PointF(20, -12)), (New-Object System.Drawing.PointF(15, -11))))
    $g.FillEllipse([System.Drawing.Brushes]::Black, 11, -15, 2.6, 2.6)
    if ($vuela) {
        $al = [Math]::Sin($fase) * 11
        $g.FillPolygon($oscuro, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(-6, -7)), (New-Object System.Drawing.PointF(4, -7)), (New-Object System.Drawing.PointF(-4, [float](-8 - $al)))))
    } else {
        $g.FillEllipse($oscuro, -7, -8, 13, 7)
        $pata = New-Object System.Drawing.Pen((C 220 90 70), 1.6)
        $g.DrawLine($pata, -2, 1, -2, 6); $g.DrawLine($pata, 3, 1, 3, 6); $pata.Dispose()
    }
    $gris.Dispose(); $oscuro.Dispose()
    $g.Restore($st)
}
# foto del videoclip como polaroid pegada con celo
function Dibujar-Polaroid($g, $img, $x, $y, $w, $ang) {
    if (-not $img) { return }
    $st = $g.Save(); $g.TranslateTransform([float]($x + $w / 2), [float]($y + $w * 0.55)); $g.RotateTransform([float]$ang)
    $h = $w * 1.12
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 120 20 40))), [float](-$w / 2 + 4), [float](-$h / 2 + 5), [float]$w, [float]$h)
    $g.FillRectangle([System.Drawing.Brushes]::White, [float](-$w / 2), [float](-$h / 2), [float]$w, [float]$h)
    $m = $w * 0.07; $lado = $w - 2 * $m
    $g.DrawImage($img, [float](-$w / 2 + $m), [float](-$h / 2 + $m), [float]$lado, [float]$lado)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 250 226 120))), [float](-$w * 0.18), [float](-$h / 2 - 6), [float]($w * 0.36), 12)
    $g.Restore($st)
}

# ================= TOKEN (femtanyl): FICHAS Y BREAKCORE =================
# Cada app es una ficha en la recreativa. Muchos clics seguidos llenan el HYPE: al máximo, ¡BREAKCORE!
$script:tkFichas = 0; $script:tkHype = 0.0; $script:tkFx = 0; $script:tkPal = New-Object System.Collections.ArrayList
$TokenPalabras = @('CH4S3R', 'P3T', 'M3SS', 'S33K H3LP', 'KATAMARI', 'ACT RIGHT', 'DINNER!', 'LOTTERY', 'HEAD UP', 'GIRL HELL 1999', 'WAR GIRL', 'H3Y', 'REACTOR')
function Token-Palabra { [void]$script:tkPal.Add(@{ Txt = (Azar $TokenPalabras); X = [double]$Rnd.Next(416, 620); Y = [double]$Rnd.Next(70, 230); T = 24; Rot = $Rnd.Next(-14, 15) }) }
$script:tkCd = 1
$TokenCanciones = @('AND IM GONE', 'DINNER!', 'MAGFEST', 'WEIGHTLESS!', 'REACTOR', 'BODY THE PISTOL', 'MIX. 01 - PICKMEUP!', 'MIX. 02 - BOTHERED!')
function Token-Portada($n) {
    $script:tkCd = $n; $a = $script:actores['K']; if (-not $a) { return }
    $pose = if ($n -eq 1) { 'main' } else { "cd$n" }
    $a.Pose = $pose; $a.Base = $pose; $a.Hasta = 0; $a.Frame = 0; Seleccionar-Frame $a
}
function Token-Clic {
    $a = $script:actores['K']; if ($a) { $a.Temblor = 10 }
    Token-Portada (($script:tkCd % 8) + 1)
    $script:tkHype = [Math]::Min(100, $script:tkHype + 22)
    Sonido 'golpe'; Token-Palabra
    if ($script:tkHype -ge 100) { Token-Breakcore } else { Decir (Azar $script:skin.Clic) }
    $form.Invalidate()
}
function Token-Breakcore {
    $script:tkHype = 0; $script:tkFx = 60
    Sonido 'breakcore'; Sacudir $form 12
    for ($i = 0; $i -lt 4; $i++) { Token-Palabra }
    Decir-Fijo (Azar @('¡¡BREAKCORE MODE!! *Todo tiembla. Token está feliz.*', '¡DROP! *Las ventanas vibran a 200 BPM.*', '¡¡MÁS ALTO!! *Se le cae una oreja. Se la vuelve a poner sin dejar de bailar.*'))
}
function Token-Tick {
    $hay = $false
    if ($script:tkHype -gt 0) { $script:tkHype = [Math]::Max(0.0, $script:tkHype - 0.35); $hay = $true }
    if ($script:tkFx -gt 0) {
        $script:tkFx--; $hay = $true
        $a = $script:actores['K']; if ($a -and $script:tkFx % 5 -eq 0) { $a.Temblor = 5 }
        if ($script:tkFx % 9 -eq 0) { Token-Palabra }
        if ($script:tkFx % 3 -eq 0) { Token-Portada ($Rnd.Next(1, 9)) }
        if ($script:tkFx % 12 -eq 0) { Sacudir $form 4 }
    }
    for ($i = $script:tkPal.Count - 1; $i -ge 0; $i--) { $w = $script:tkPal[$i]; $w.T--; $w.Y -= 1.2; $hay = $true; if ($w.T -le 0) { $script:tkPal.RemoveAt($i) } }
    if ($hay) { $form.Invalidate() }
}

# ================= TETRA (YonKaGor): MENSAJES Y NO MOLESTAR =================
# Cada app trae un mensaje de "neems". Cada cuatro clics, Tetra se pone (o se quita) el No molestar.
$script:popMsgs = 0; $script:popDND = $false; $script:popNoti = $null; $script:popClics = 0; $script:popFx = 0
$script:popIni = [Environment]::TickCount; $script:peces = New-Object System.Collections.ArrayList
function Tetra-Mensaje {
    $script:popMsgs++
    if ($script:popDND) { return $false }
    $script:popNoti = @{ T = 80; Txt = (Azar @('hey', '¿sigues ahí?', 'mira esto jaja', '¿una partida?', '¿te acuerdas de 2020?', 'buenas noches :)', '¿has visto mi historia?', 'jajaja', 'te echo de menos', '¿llamada luego?')) }
    Sonido 'ping'; return $true
}
function Tetra-Clic {
    $a = $script:actores['E']; if ($a) { $a.Salto = 12 }
    $script:popClics++; $script:popFx = 8
    if ($script:popClics % 4 -eq 0) {
        $script:popDND = -not $script:popDND; Sonido 'vhs'
        if ($script:popDND) { Decir 'No molestar: ACTIVADO. *Se pone los cascos.* No es nada personal.' }
        else { Decir 'No molestar: desactivado. Ya me pueden escribir. ...igual tardo en contestar.' }
    } elseif ($Rnd.Next(3) -eq 0) {
        Sonido 'disco'; $script:popBaila = 90
        Decir (Azar @('*Se pone a bailar disco en el sitio.* Esto sonaba mucho en 2020.', '*Baila un poco. Se le mueven los pendientes de pez.*', '*Tararea muy bajito.* ...you''re just like pop music...'))
    } else { Decir (Azar $script:skin.Clic) }
    $form.Invalidate()
}
# su canción ("You're Just Like Pop Music", la versión instrumental oficial) suena de fondo, como la de Gran
$script:popMusica = $null; $script:popBaila = 0; $script:burbujas = New-Object System.Collections.ArrayList
function Tetra-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.5 * $script:aj.Volumen / 100.0)) }
# la instrumental va 4,805 s por detrás del videoclip (medido comparando las dos pistas): así, al acabar la intro,
# la canción sigue justo por donde iba el vídeo. $desdeMs = milisegundos de la instrumental donde empezar.
$TetraDesfase = 4805; $TetraIntroDesde = 3800   # la intro empieza en el segundo 3,8 del vídeo (sin el aviso de epilepsia)
function Tetra-Musica-On($desdeMs) {
    if (-not $script:aj.Sonido -or $script:popMusica) { return }
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta 'skins\tetra\cancion.mp3')); $mp.Volume = (Tetra-Volumen)
        $script:popDesde = 0
        if ($desdeMs -gt 0) { $mp.Position = [TimeSpan]::FromMilliseconds($desdeMs); $script:popDesde = [double]$desdeMs; $script:popDesdeT = [Environment]::TickCount }
        $mp.Play()
        $script:popMusica = $mp
    } catch { $script:popMusica = $null }
}
function Tetra-Musica-Off {
    if ($script:popMusica) { try { $script:popMusica.Stop(); $script:popMusica.Close() } catch {}; $script:popMusica = $null }
}
# un pez nuevo: nada hacia la derecha o la izquierda, en uno de los dos bancos (arriba o en medio)
function Tetra-Pez-Nuevo($fuera) {
    $dir = if ($Rnd.Next(2) -eq 0) { 1 } else { -1 }
    $banco = if ($Rnd.Next(2) -eq 0) { 100 } else { 190 }
    $x = if ($fuera) { $(if ($dir -gt 0) { 380 - $Rnd.Next(0, 120) } else { 790 + $Rnd.Next(0, 120) }) } else { $Rnd.Next(410, 760) }
    return @{ X = [double]$x; Y = [double]($banco + $Rnd.Next(-26, 26)); Y0 = [double]$banco; V = $dir * (0.7 + $Rnd.NextDouble() * 0.9); E = 0.75 + $Rnd.NextDouble() * 0.5; F = $Rnd.NextDouble() * 6 }
}
function Tetra-Tick {
    # la canción: se repite al acabar, sigue el volumen y se calla si quitas el sonido
    # (durante la intro suena el audio del vídeo; la instrumental entra al acabar, por el mismo punto)
    if ($script:transicion -and $script:ppAudio) { }
    elseif (-not $script:aj.Sonido) { Tetra-Musica-Off }
    elseif (-not $script:popMusica) { Tetra-Musica-On }
    else {
        try {
            $mp = $script:popMusica
            if ([Math]::Abs($mp.Volume - (Tetra-Volumen)) -gt 0.01) { $mp.Volume = (Tetra-Volumen) }
            # el mp3 tarda un poco en abrirse y arranca retrasado: los primeros 3 s se recoloca si se desvía
            if ($script:popDesde -gt 0) {
                $pasado = [Environment]::TickCount - $script:popDesdeT
                if ($pasado -gt 3000) { $script:popDesde = 0 }
                elseif ($mp.NaturalDuration.HasTimeSpan) {
                    $quiero = $script:popDesde + $pasado
                    if ([Math]::Abs($mp.Position.TotalMilliseconds - $quiero) -gt 200.0) { $mp.Position = [TimeSpan]::FromMilliseconds($quiero) }
                }
            }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # los tetras neón nadan en bancos, ondulando un poco; al salir por un lado vuelven a entrar
    if ($script:peces.Count -eq 0) { for ($i = 0; $i -lt 12; $i++) { [void]$script:peces.Add((Tetra-Pez-Nuevo $false)) } }
    foreach ($p in $script:peces) {
        $p.X += $p.V; $p.F += 0.25; $p.Y += ($p.Y0 + [Math]::Sin(($p.X + $p.Y0) / 40.0) * 18 - $p.Y) * 0.02
        if (($p.V -gt 0 -and $p.X -gt 800) -or ($p.V -lt 0 -and $p.X -lt 370)) { $n = Tetra-Pez-Nuevo $true; foreach ($c in @($n.Keys)) { $p[$c] = $n[$c] } }
    }
    # burbujas que suben del burbujeador
    if ($Rnd.Next(5) -eq 0) { [void]$script:burbujas.Add(@{ X = 479.0 + $Rnd.Next(-3, 4); Y = 284.0; R = 2 + $Rnd.Next(0, 4); F = $Rnd.NextDouble() * 6 }) }
    for ($i = $script:burbujas.Count - 1; $i -ge 0; $i--) { $bu = $script:burbujas[$i]; $bu.Y -= 1.1 + $bu.R * 0.15; $bu.F += 0.15; if ($bu.Y -lt 60) { $script:burbujas.RemoveAt($i) } }
    # baila un rato (cuando le da por la música disco) y luego vuelve a estar tranquila
    $a = $script:actores['E']
    if ($a) { if ($script:popBaila -gt 0) { $script:popBaila--; $a.Baila = $true } else { $a.Baila = $false } }
    if ($script:popNoti) { $script:popNoti.T--; if ($script:popNoti.T -le 0) { $script:popNoti = $null } }
    if ($script:popFx -gt 0) { $script:popFx-- }
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](276 * $script:K), [int](410 * $script:K), [int](44 * $script:K))))
}
# pececito neón (tetra neón): cuerpo plateado, franja azul brillante y cola roja (esc negativo = mira a la izquierda)
function Dibujar-Tetra-Pez($g, $x, $y, $esc, $fase) {
    $st = $g.Save(); $g.TranslateTransform([float]$x, [float]$y); $g.ScaleTransform([float]$esc, [float][Math]::Abs($esc))
    $cola = [Math]::Sin($fase) * 2
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 200 240 60 70))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(-9, 0)), (New-Object System.Drawing.PointF(-16, [float](-4 + $cola))), (New-Object System.Drawing.PointF(-16, [float](4 + $cola)))))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 210 220 230 240))), -11, -4, 22, 8)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 230 255 70 90))), -10, 0, 9, 3)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 255 60 230 255))), -8, -2, 17, 2)
    $g.FillEllipse([System.Drawing.Brushes]::Black, 6, -2, 2.5, 2.5)
    $g.Restore($st)
}
# copia de una imagen pintada de un solo color (para el efecto de colores separados de VHS / glitch)
function Imagen-Color($img, $col, $alto) {
    if (-not $img) { return $null }
    $ancho = [Math]::Max(1, [int]($img.Width * $alto / $img.Height))
    $b = New-Object System.Drawing.Bitmap($ancho, [int]$alto)
    $g = [System.Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'HighQualityBicubic'
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = 0; $cm.Matrix11 = 0; $cm.Matrix22 = 0; $cm.Matrix40 = $col.R / 255.0; $cm.Matrix41 = $col.G / 255.0; $cm.Matrix42 = $col.B / 255.0
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $ancho, [int]$alto)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.Dispose(); $ia.Dispose(); return $b
}
# imagen con los colores separados (rojo/cian) como en una tele vieja
function Dibujar-RGB($g, $img, $c1, $c2, $x, $y, $w, $h, $sep) {
    if ($c1) { $g.DrawImage($c1, [float]($x - $sep), [float]$y, [float]$w, [float]$h) }
    if ($c2) { $g.DrawImage($c2, [float]($x + $sep), [float]$y, [float]$w, [float]$h) }
    if ($img) { $g.DrawImage($img, [float]$x, [float]$y, [float]$w, [float]$h) }
}
# ================= KEVIN (Don't Touch My Pizza): SU PIZZA =================
# Cada app que abres es un trozo que se come. Si tocas la pizza, se enfada: cuchillo y pistola,
# luego "I'm going to bite you" y a la tercera, motosierra y fuego. A veces aparece queso azul:
# ese sí lo puedes quitar (haz clic en la pizza) y te lo agradece.
$script:pzTrozos = 8; $script:pzComidas = 0; $script:pzEnfado = 0.0; $script:pzQueso = $false; $script:pzFx = 0
$script:pzReparto = 0; $script:pzGrito = $null; $script:pzLluvia = New-Object System.Collections.ArrayList
$PizzaX = 452; $PizzaY = 224; $PizzaR = 30
$script:pzRect = @(498, 90, 248, 172); $script:pzLienzo = @(414, 90, 334, 172)
function Dibujar-Trozo($g, $x, $y, $s, $ang) {
    # un trozo de pizza: triángulo de queso con borde de masa y pepperoni
    $st = $g.Save(); $g.TranslateTransform([float]$x, [float]$y); $g.RotateTransform([float]$ang); $g.ScaleTransform([float]($s / 20.0), [float]($s / 20.0))
    $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 12)), (New-Object System.Drawing.PointF(-10, -9)), (New-Object System.Drawing.PointF(10, -9)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 255 206 84))), $pts)
    $g.DrawPolygon((New-Object System.Drawing.Pen((C 120 60 20), 1.2)), $pts)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 210 140 60))), -11, -12, 22, 5)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 60 20), 1.2)), -11, -12, 22, 5)
    foreach ($q in @(@(-4, -3), @(3, -2), @(0, 4))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 210 40 40))), [float]($q[0] - 2.2), [float]($q[1] - 2.2), 4.4, 4.4) }
    $g.Restore($st)
}
function Dibujar-Pizza($g, $cx, $cy, $r, $trozos, $queso) {
    # plato
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 60 0 0 0))), [float]($cx - $r - 6), [float]($cy - $r * 0.25 + $r), [float](2 * $r + 12), [float]($r * 0.5))
    $g.FillEllipse([System.Drawing.Brushes]::White, [float]($cx - $r - 7), [float]($cy - $r - 7), [float](2 * $r + 14), [float](2 * $r + 14))
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 30 30 30), 2)), [float]($cx - $r - 7), [float]($cy - $r - 7), [float](2 * $r + 14), [float](2 * $r + 14))
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 180 190 200), 1)), [float]($cx - $r - 3), [float]($cy - $r - 3), [float](2 * $r + 6), [float](2 * $r + 6))
    if ($trozos -le 0) { return }
    $masa = New-Object System.Drawing.SolidBrush((C 214 146 64)); $queso1 = New-Object System.Drawing.SolidBrush((C 255 206 84))
    $tinta = New-Object System.Drawing.Pen((C 30 30 30), 1.6)
    for ($i = 0; $i -lt $trozos; $i++) {
        $a0 = -90 + $i * 45
        $g.FillPie($masa, [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r), [float]$a0, 45)
        $g.FillPie($queso1, [float]($cx - $r + 5), [float]($cy - $r + 5), [float](2 * $r - 10), [float](2 * $r - 10), [float]$a0, 45)
        $g.DrawPie($tinta, [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r), [float]$a0, 45)
        # pepperoni
        foreach ($q in @(@(0.55, 14), @(0.75, 32))) {
            $an = ($a0 + $q[1]) * [Math]::PI / 180; $px = $cx + [Math]::Cos($an) * $r * $q[0]; $py = $cy + [Math]::Sin($an) * $r * $q[0]
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 206 40 40))), [float]($px - 3.5), [float]($py - 3.5), 7, 7)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 255 140 120))), [float]($px - 2), [float]($py - 2.5), 3, 2)
        }
    }
    $masa.Dispose(); $queso1.Dispose(); $tinta.Dispose()
    if ($queso) {
        # queso azul encima y olor que sube
        $azul = New-Object System.Drawing.SolidBrush((C 120 160 210)); $vena = New-Object System.Drawing.SolidBrush((C 50 80 150))
        foreach ($q in @(@(-12, -6), @(8, -12), @(4, 8), @(-6, 12), @(14, 4))) {
            $g.FillEllipse($azul, [float]($cx + $q[0] - 6), [float]($cy + $q[1] - 5), 12, 10)
            $g.FillEllipse($vena, [float]($cx + $q[0] - 2), [float]($cy + $q[1] - 2), 3, 3)
        }
        $azul.Dispose(); $vena.Dispose()
        $olor = New-Object System.Drawing.Pen((ARGB 200 110 190 60), 2.5)
        for ($i = 0; $i -lt 3; $i++) {
            $ox = $cx - 14 + $i * 14; $f = $script:fase * 2 + $i
            $g.DrawBezier($olor, [float]$ox, [float]($cy - $r - 6), [float]($ox + 8 * [Math]::Sin($f)), [float]($cy - $r - 16), [float]($ox - 8 * [Math]::Sin($f)), [float]($cy - $r - 26), [float]$ox, [float]($cy - $r - 36))
        }
        $olor.Dispose()
    }
}
function Pizza-En-Raton {
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    return ([Math]::Pow($x - $PizzaX, 2) + [Math]::Pow($y - $PizzaY, 2) -le [Math]::Pow($PizzaR + 8, 2))
}
# poses que ocupan todo el lienzo de Paint (fuego y unicornio)
function Kevin-Grande($pose, $ms) {
    $a = $script:actores['V']; if (-not $a) { return }
    $a.Rect = $script:pzLienzo; $a.Llenar = $true
    Actor-Pose 'V' $pose $ms
}
function Kevin-Comer($linea) {
    if ($script:pzTrozos -le 0) { Decir "$linea (Kevin mira el plato vacío. La pizza nueva está en camino.)"; return }
    $script:pzTrozos--; Sonido 'nam'
    Flotante 'ÑAM' ($PizzaX - 22) ($PizzaY - 50) (C 70 200 40) 22 'Comic Sans MS'
    if ($script:pzTrozos -le 0) {
        $script:pzComidas++; $script:pzReparto = 50
        Actor-Pose 'V' 'feliz' 1500
        Decir "$linea ...¡Y se acabó la pizza! *Llama al repartidor.*"
    } else {
        if ($Rnd.Next(3) -eq 0) { Actor-Pose 'V' 'chulo' 1400 }
        Decir $linea
    }
    $form.Invalidate()
}
function Pizza-Tocar {
    if (Ocupado) { return }
    $k = $script:skin
    if ($script:pzQueso) {
        # quitar el queso azul es lo único que se le puede hacer a su pizza
        $script:pzQueso = $false; $a = $script:actores['V']; if ($a) { $a.Base = 'main' }
        Sonido 'pop'; Actor-Pose 'V' 'feliz' 1800
        Flotante '¡GRACIAS!' ($PizzaX - 40) ($PizzaY - 52) (C 255 110 200) 18 'Comic Sans MS'
        Decir (Azar @('¡Gracias! ¡Fuera queso azul! Huele fatal, de verdad. Puedes... no, no puedes tocar la pizza. Pero gracias.', '*Respira hondo.* ¡Aire limpio! Eres de los buenos. Pero la pizza sigue sin tocarse.', '¡Me has salvado! El queso azul es mi enemigo mortal. Bueno, el segundo. El primero es el que toca mi pizza.'))
        $form.Invalidate(); return
    }
    $script:pzEnfado = [Math]::Min(100, $script:pzEnfado + 38)
    # el grito grande (en el segundo aviso no: ese GIF ya lleva su propio texto)
    $script:pzGrito = if ($script:pzEnfado -ge 60 -and $script:pzEnfado -lt 100) { $null } else { @{ Txt = "DON'T TOUCH MY PIZZA!"; T = 30 } }
    if ($script:pzEnfado -ge 100) {
        # tercer aviso: motosierra y fuego
        $script:pzFx = 80; Sonido 'grito'; Sacudir $form 16
        Actor-Pose 'V' 'motosierra' 1700
        Decir-Fijo (Azar $k.Rabia)
    } elseif ($script:pzEnfado -ge 60) {
        Sonido 'grr'; Sacudir $form 6; Actor-Pose 'V' 'muerde' 2600; Actor-Golpe 'V'
        Decir (Azar $k.Toque2)
    } else {
        Sonido 'grr'; Actor-Pose 'V' 'arma' 2400
        Decir (Azar $k.Toque1)
    }
    $form.Invalidate()
}
function Kevin-Clic {
    $k = $script:skin; $r = $Rnd.Next(100)
    if ($r -lt 4) {
        Sonido 'baile'; Kevin-Grande 'unicornio' 6000
        Decir '*Se sube a un unicornio y cabalga por el arcoíris.* ¡ADIÓS, MUNDO! ...vuelvo en seis segundos.'
    } elseif ($r -lt 34) {
        Sonido 'baile'; Actor-Pose 'V' 'baile' 4300
        foreach ($i in 0..3) { Flotante (Azar @('♪', '♫')) (520 + $i * 50) (96 + $Rnd.Next(40)) (@((C 70 200 40), (C 30 100 240), (C 255 110 200), (C 70 200 40))[$i]) 22 'Segoe UI Symbol' }
        Decir (Azar @('*Baila como en 2010.* ¡Mira qué pasos!', '*Baila.* ¡Esto es lo que hago cuando nadie toca mi pizza!', '*Baila sin ritmo pero con muchas ganas.*'))
    } elseif ($r -lt 52) {
        Actor-Pose 'V' 'micro' 5000
        foreach ($i in 0..2) { Flotante '♪' (540 + $i * 60) (100 + $Rnd.Next(30)) (C 255 110 200) 22 'Segoe UI Symbol' }
        Decir (Azar @('*Coge un micro.* ¡Esta va por todos los que NO tocan mi pizza!', '*Canta con chaqueta y todo.* Don''t touch my pizza~ ♪', '¡Un, dos, un, dos! *Golpea el micro.* ¿Se oye? ¡NO TOQUÉIS MI PIZZA!'))
    } elseif ($r -lt 66) {
        Actor-Pose 'V' 'feliz' 1500; Decir (Azar @('¡YAAAY!', '¡Hola! ¡Hola! ¡HOLA!', '*Levanta los brazos.* ¡SOY FELIZ! Tengo pizza.'))
    } elseif ($r -lt 76) {
        Actor-Pose 'V' 'piensa' 2600; Decir (Azar @('*Piensa.* ¿Y si la pizza fuera de mermelada? ...no. Eso es un crimen.', '*Piensa muy fuerte.* ...se me ha olvidado lo que pensaba. Algo de pizza.', 'Hmm. ¿Tú tienes cara de tocar pizzas ajenas? *Te mira entrecerrando los ojos.*'))
    } else {
        Actor-Pose 'V' 'chulo' 1600; Decir (Azar $k.Clic)
    }
    $form.Invalidate()
}
function Kevin-Queso {
    if ($script:pzQueso -or $script:pzTrozos -le 0) { return $false }
    $script:pzQueso = $true; Sonido 'grr'
    $a = $script:actores['V']; if ($a) { $a.Base = 'sudor'; Actor-Pose 'V' 'grita' 1600 }
    Decir (Azar @('¡¿QUIÉN HA PUESTO QUESO AZUL EN MI PIZZA?! ¡Huele fatal! (haz clic en la pizza para quitarlo)', '*Huele.* ...¡PUAJ! ¡QUESO AZUL! Quítalo, quítalo, quítalo. (clic en la pizza)', 'No me gusta el queso azul porque huele muy mal. ¡Y ahora está EN MI PIZZA! (clic en la pizza para quitarlo)')) 'serio'
    $form.Invalidate(); return $true
}
function Kevin-Tick {
    $hay = $false
    $a = $script:actores['V']
    # vuelve a su sitio después del fuego o del unicornio
    if ($a -and $a.Llenar -and $a.Pose -notin @('fuego', 'unicornio')) { $a.Rect = $script:pzRect; $a.Llenar = $false; $hay = $true }
    if ($script:pzEnfado -gt 0 -and $script:pzFx -le 0) { $script:pzEnfado = [Math]::Max(0.0, $script:pzEnfado - 0.3); $hay = $true }
    if ($script:pzFx -gt 0) {
        $script:pzFx--; $hay = $true
        if ($script:pzFx -eq 52) { Kevin-Grande 'fuego' 2600; Sonido 'grr' }
        if ($script:pzFx % 10 -eq 0) { Sacudir $form 5 }
        if ($script:pzFx % 3 -eq 0) { [void]$script:pzLluvia.Add(@{ X = [double]$Rnd.Next(420, 740); Y = 70.0; V = 2.5 + $Rnd.NextDouble() * 3; A = $Rnd.Next(0, 360); Fuego = $true }) }
        if ($script:pzFx -eq 0) { $script:pzEnfado = 45 }
    }
    if ($script:pzReparto -gt 0) {
        $script:pzReparto--
        if ($script:pzReparto -eq 0) {
            $script:pzTrozos = 8; Sonido 'ding'; Actor-Pose 'V' 'feliz' 1600
            for ($i = 0; $i -lt 8; $i++) { [void]$script:pzLluvia.Add(@{ X = [double]$Rnd.Next(420, 740); Y = 60.0 - $Rnd.Next(0, 40); V = 2 + $Rnd.NextDouble() * 2; A = $Rnd.Next(0, 360); Fuego = $false }) }
            if (-not $script:discutiendo) { Decir (Azar @('*Ding dong.* ¡¡PIZZA NUEVA!! *La abraza.* Hola, preciosa.', '*Ding dong.* ¡Ha llegado el repartidor! Ocho trozos. Todos míos.', '*Ding dong.* ¡PIZZA! ...que nadie se acerque. Ni tú.')) 'abiertos' }
        }
        $hay = $true
    }
    for ($i = $script:pzLluvia.Count - 1; $i -ge 0; $i--) { $t = $script:pzLluvia[$i]; $t.Y += $t.V; $t.A += 7; $hay = $true; if ($t.Y -gt 270) { $script:pzLluvia.RemoveAt($i) } }
    if ($script:pzGrito) { $script:pzGrito.T--; $hay = $true; if ($script:pzGrito.T -le 0) { $script:pzGrito = $null } }
    if ($script:pzQueso) { $hay = $true }
    if ($hay) { $form.Invalidate() }
}
# elige el fotograma de un GIF según el tiempo (para las intros)
function Gif-Frame($img, $info, $ms) {
    if (-not $img -or $info.N -le 1) { return }
    $tot = 0; foreach ($d in $info.Del) { $tot += $d }
    $t = $ms % $tot; $i = 0
    while ($i -lt $info.N - 1 -and $t -ge $info.Del[$i]) { $t -= $info.Del[$i]; $i++ }
    [void]$img.SelectActiveFrame((New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])), $i)
}

# ================= GRAN: ANTIHUMAN INC. =================
# Su canción ("Are You Sure He's a Pharmacist?") suena de fondo mientras la skin está puesta (si el sonido está activado).
# Cada app que abres es un sujeto de prueba que recibe una dosis de Fury Mix: unas veces sale un furry nuevo y otras falla.
# Haz clic en Gran y se tapa la cara, como en el vídeo. Como invitado en las discusiones sale siempre con la cara tapada.
$script:gr = $null; $script:grMusica = $null
function Gran-Reset { if (-not $script:gr) { $script:gr = @{ Sujetos = 0; Exitos = 0; Tapa = 0; Fx = 0; FxCol = (C 32 208 44) } } }
function Gran-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.7 * $script:aj.Volumen / 100.0)) }
function Gran-Musica-On($desdeCero) {
    if (-not $script:aj.Sonido) { return }
    if ($script:grMusica -and -not $desdeCero) { return }
    Gran-Musica-Off
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta 'skins\gran\cancion.mp3')); $mp.Volume = (Gran-Volumen); $mp.Play()
        $script:grMusica = $mp
    } catch { $script:grMusica = $null }
}
function Gran-Musica-Off {
    if ($script:grMusica) { try { $script:grMusica.Stop(); $script:grMusica.Close() } catch {}; $script:grMusica = $null }
}
# se tapa la cara (con la transición del vídeo) durante unos milisegundos
function Gran-Tapar($ms) {
    $a = $script:actores['G']; if (-not $a -or -not $script:gr) { return }
    if ($a.Base -ne 'tapada') { $a.Base = 'tapada'; Actor-Pose 'G' 'tapar' 360 }
    $script:gr.Tapa = [Environment]::TickCount + $ms
}
function Gran-Clic {
    Gran-Tapar 5000
    Decir (Azar $script:skin.Clic)
}
# una app abierta = un sujeto de prueba
function Gran-Dosis($linea) {
    $e = $script:gr; if (-not $e) { Decir $linea; return }
    $e.Sujetos++
    if ($Rnd.Next(100) -lt 62) {
        $e.Exitos++; $e.Fx = 10; $e.FxCol = (C 32 208 44)
        Flotante '+1 FURRY' 160 262 (C 32 208 44) 20 'Bahnschrift'
    } else {
        $e.Fx = 10; $e.FxCol = (C 200 30 60)
        Flotante 'FALLIDO' 160 262 (C 230 50 70) 20 'Bahnschrift'
    }
    if ($e.Sujetos % 10 -eq 0) {
        $pc = [int](100 * $e.Exitos / $e.Sujetos)
        Gran-Tapar 6000
        Decir-Fijo "Informe para el consejo: $($e.Sujetos) sujetos, $pc % de éxito. $(if ($pc -ge 60) { 'Aceptable. La especie superior avanza.' } else { 'Insuficiente. Subiré la dosis.' })" 'abiertos'
    } else { Decir $linea }
    $form.Invalidate()
}
function Gran-Tick {
    $e = $script:gr; if (-not $e) { return }
    # la canción: se repite al acabar, sigue el volumen y se calla si quitas el sonido
    if (-not $script:aj.Sonido) { Gran-Musica-Off }
    elseif (-not $script:grMusica) { Gran-Musica-On $false }
    else {
        try {
            $mp = $script:grMusica
            if ([Math]::Abs($mp.Volume - (Gran-Volumen)) -gt 0.01) { $mp.Volume = (Gran-Volumen) }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # vuelve a destaparse
    if ($e.Tapa -gt 0 -and [Environment]::TickCount -ge $e.Tapa) {
        $e.Tapa = 0; $a = $script:actores['G']
        if ($a) { $a.Base = 'main'; Actor-Pose 'G' 'main' 0 }
        $e.Fx = 6; $e.FxCol = (C 32 208 44)
    }
    if ($e.Fx -gt 0) { $e.Fx--; Invalidar-Escena }
}

# ================= KENNYOUNG: SU VIDA EN SUS VÍDEOS =================
# Kenny vive en los escenarios de sus videoclips (imágenes sin letras en skins\kennyoung\escenas) y su ÁNIMO decide en
# cuál está, con la canción de ese vídeo sonando (skins\kennyoung\musica):
#   animado (Ready To Say: el paseo al atardecer)  ·  tranquilo (I Used To: el salón)  ·  solo (Loner: su cuarto de
#   noche, con la manta)  ·  cansado (Lethargy)  ·  agobiado (Get Away).
# ENERGÍA: baja con el tiempo y con cada app; sube si le dejas descansar. COMPAÑÍA: sube con clics y apps; baja si le
# ignoras. AGOBIO: sube si abres muchas apps seguidas; baja solo. Clic en "animado" = toca (el ampli sube y, al 100 %,
# la guitarra EXPLOTA); en las otras escenas, le haces compañía, le animas o le calmas.
$KyEscenas = @{
    animado = @{ Img = 'skins\kennyoung\escenas\animado.jpg'; Musica = 'readytosay'; Cancion = 'Ready To Say'; Nombre = 'con ganas de tocar' }
    tranquilo = @{ Img = 'skins\kennyoung\escenas\tranquilo.jpg'; Musica = 'iusedto'; Cancion = 'I Used To'; Nombre = 'tranquilo' }
    solo = @{ Img = 'skins\kennyoung\escenas\solo.jpg'; Musica = 'loner'; Cancion = 'Loner'; Nombre = 'solo' }
    cansado = @{ Img = 'skins\kennyoung\escenas\cansado.jpg'; Musica = 'lethargy'; Cancion = 'Lethargy'; Nombre = 'sin energía' }
    agobiado = @{ Img = 'skins\kennyoung\escenas\agobiado.jpg'; Musica = 'getaway'; Cancion = 'Get Away'; Nombre = 'agobiado' }
}
$KyTiempos = @{ EnergiaApp = 5.0; CompaniaApp = 3.0; AgobioApp = 18.0; CompaniaClic = 9.0; Descanso = 40000; CambioMin = 6000; Fundido = 900 }
$script:ky = $null; $script:kyMusica = $null; $script:kyMusicaVieja = $null; $script:kyMusNom = ''; $script:kyPosiciones = @{}; $script:kyImgs = @{}
function Ky-Reset {
    if (-not $script:ky) {
        $script:ky = @{ Escena = 'tranquilo'; Antes = $null; CambioT = 0; Energia = 70.0; Compania = 60.0; Agobio = 0.0; Ult = [Environment]::TickCount
            Amp = 0.0; Rotas = 0; Fx = 0; Flash = 0; Desde = 0; DesdeT = 0; Fade = 1.0 }
    }
}
function Ky-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.45 * $script:aj.Volumen / 100.0)) }
function Ky-Musica-Off {
    foreach ($m in @($script:kyMusica, $script:kyMusicaVieja)) { if ($m) { try { $m.Stop(); $m.Close() } catch {} } }
    $script:kyMusica = $null; $script:kyMusicaVieja = $null; $script:kyMusNom = ''
}
# cambia de canción con un fundido; cada canción sigue por donde se dejó
function Ky-Poner-Musica($nombre, $desdeMs) {
    Ky-Reset; $e = $script:ky
    if ($null -eq $desdeMs -and $script:kyMusica -and $script:kyMusNom -eq $nombre) { return }   # ya suena (p. ej. la de la intro)
    if ($script:kyMusica) {
        try { $script:kyPosiciones[$script:kyMusNom] = $script:kyMusica.Position.TotalMilliseconds } catch {}
        if ($script:kyMusicaVieja) { try { $script:kyMusicaVieja.Stop(); $script:kyMusicaVieja.Close() } catch {} }
        $script:kyMusicaVieja = $script:kyMusica; $script:kyMusica = $null
    }
    $script:kyMusNom = $nombre
    if (-not $script:aj.Sonido) { return }
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta ('skins\kennyoung\musica\' + $nombre + '.mp3'))); $mp.Volume = 0.0
        if ($null -eq $desdeMs -and $script:kyPosiciones.ContainsKey($nombre)) { $desdeMs = $script:kyPosiciones[$nombre] }
        $e.Desde = 0
        if ($desdeMs -gt 0) { $mp.Position = [TimeSpan]::FromMilliseconds($desdeMs); $e.Desde = [double]$desdeMs; $e.DesdeT = [Environment]::TickCount }
        $mp.Play(); $script:kyMusica = $mp; $e.Fade = 0.0
    } catch { $script:kyMusica = $null }
}
# en qué escena debería estar según su ánimo
function Ky-Escena-Deseada {
    $e = $script:ky
    if ($e.Agobio -ge 70.0) { return 'agobiado' }
    if ($e.Energia -lt 25.0) { return 'cansado' }
    if ($e.Compania -lt 25.0) { return 'solo' }
    if ($e.Energia -ge 60.0 -and $e.Compania -ge 55.0) { return 'animado' }
    return 'tranquilo'
}
function Ky-Cambiar($esc) {
    $e = $script:ky; $k = $script:skin
    $e.Antes = $e.Escena; $e.Escena = $esc; $e.CambioT = [Environment]::TickCount
    if (-not $script:transicion) { Ky-Poner-Musica $KyEscenas[$esc].Musica $null }
    if (-not (Ocupado) -and -not $script:discutiendo) { Decir (Azar $k[('Entra' + $esc.Substring(0, 1).ToUpper() + $esc.Substring(1))]) }
    $form.Invalidate()
}
function Ky-App($linea) {
    Ky-Reset; $e = $script:ky; $k = $script:skin
    $e.Energia = [Math]::Max(0.0, $e.Energia - $KyTiempos.EnergiaApp); $e.Compania = [Math]::Min(100.0, $e.Compania + $KyTiempos.CompaniaApp)
    $e.Agobio = [Math]::Min(100.0, $e.Agobio + $KyTiempos.AgobioApp); $e.Ult = [Environment]::TickCount
    Sonido 'acorde'
    if ($e.Escena -eq 'agobiado') { Decir (Azar $k.AppAgobiado); return }
    if ($e.Escena -eq 'cansado') { Decir (Azar $k.AppCansado); return }
    Decir $linea
}
function Ky-Clic {
    Ky-Reset; $e = $script:ky; $k = $script:skin
    $e.Ult = [Environment]::TickCount; $e.Compania = [Math]::Min(100.0, $e.Compania + $KyTiempos.CompaniaClic)
    switch ($e.Escena) {
        'animado' {
            # toca: el ampli sube; al 100 % la guitarra explota
            $e.Amp = [Math]::Min(100.0, $e.Amp + 22)
            Sonido 'acorde'
            foreach ($i in 0..1) { Flotante (Azar @('♪', '♫', '★')) (560 + $Rnd.Next(0, 180)) (80 + $Rnd.Next(0, 90)) (@((C 255 255 255), (C 255 80 160), (C 110 235 140))[$Rnd.Next(3)]) 22 'Segoe UI Symbol' }
            if ($e.Amp -ge 100.0) {
                $e.Amp = 0.0; $e.Rotas++; $e.Fx = 50; if (-not $script:aj.Epilepsia) { $e.Flash = 8 }
                $e.Energia = [Math]::Max(0.0, $e.Energia - 15)
                Sonido 'kaboom'; Sacudir $form 14
                Decir-Fijo (Azar $k.Kaboom)
            } elseif ($e.Amp -ge 70.0) { Decir (Azar $k.AmpAlto) }
            else { Decir (Azar $k.Clic) }
        }
        'agobiado' { $e.Agobio = [Math]::Max(0.0, $e.Agobio - 15); Decir (Azar $k.ClicAgobiado) }
        'cansado' { $e.Energia = [Math]::Min(100.0, $e.Energia + 3); Decir (Azar $k.ClicCansado) }
        'solo' { $e.Compania = [Math]::Min(100.0, $e.Compania + 6); Flotante '♥' 640 120 (C 255 150 190) 20 'Segoe UI Symbol'; Decir (Azar $k.ClicSolo) }
        default { Decir (Azar $k.ClicTranquilo) }
    }
    $form.Invalidate()
}
function Ky-Tick {
    Ky-Reset; $e = $script:ky; $k = $script:skin; $ahora = [Environment]::TickCount
    $a = $script:actores['Y']; if ($a -and $a.Visible) { $a.Visible = $false }   # Kenny ya sale en cada escena
    # su ánimo
    $descansa = ($ahora - $e.Ult) -gt $KyTiempos.Descanso
    if ($descansa) { $e.Energia = [Math]::Min(100.0, $e.Energia + 0.05); $e.Compania = [Math]::Max(0.0, $e.Compania - 0.02) }
    else { $e.Energia = [Math]::Max(0.0, $e.Energia - 0.01); $e.Compania = [Math]::Max(0.0, $e.Compania - 0.006) }
    $e.Agobio = [Math]::Max(0.0, $e.Agobio - 0.06)
    if (-not $script:transicion) {
        $quiere = Ky-Escena-Deseada
        if ($quiere -ne $e.Escena -and ($ahora - $e.CambioT) -gt $KyTiempos.CambioMin) { Ky-Cambiar $quiere }
    }
    # la música: la de su escena (con fundido), sigue el volumen y se repite al acabar
    if (-not $script:aj.Sonido) { Ky-Musica-Off }
    elseif (-not $script:transicion -and $script:kyMusNom -ne $KyEscenas[$e.Escena].Musica) { Ky-Poner-Musica $KyEscenas[$e.Escena].Musica $null }
    if ($script:kyMusica) {
        try {
            $mp = $script:kyMusica
            if ($e.Fade -lt 1.0) { $e.Fade = [Math]::Min(1.0, $e.Fade + 0.05) }
            $vt = (Ky-Volumen) * $e.Fade; if ([Math]::Abs($mp.Volume - $vt) -gt 0.01) { $mp.Volume = $vt }
            if ($e.Desde -gt 0) {
                $pasado = $ahora - $e.DesdeT
                if ($pasado -gt 3000) { $e.Desde = 0 }
                elseif ($mp.NaturalDuration.HasTimeSpan) { $quiero = $e.Desde + $pasado; if ([Math]::Abs($mp.Position.TotalMilliseconds - $quiero) -gt 250.0) { $mp.Position = [TimeSpan]::FromMilliseconds($quiero) } }
            }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(150))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    if ($script:kyMusicaVieja) {
        try { $v = $script:kyMusicaVieja.Volume - 0.03; if ($v -le 0) { $script:kyMusicaVieja.Stop(); $script:kyMusicaVieja.Close(); $script:kyMusicaVieja = $null } else { $script:kyMusicaVieja.Volume = $v } } catch { $script:kyMusicaVieja = $null }
    }
    if ($e.Amp -gt 0) { $e.Amp = [Math]::Max(0.0, $e.Amp - 0.4) }
    if ($e.Fx -gt 0) { $e.Fx--; if ($e.Fx % 8 -eq 0) { Sacudir $form 3 } }
    if ($e.Flash -gt 0) { $e.Flash-- }
    if ($script:aj.Epilepsia) { $e.Flash = 0 }
    $form.Invalidate()
}
function Ky-Img($esc) {
    if (-not $script:kyImgs.ContainsKey($esc)) { $script:kyImgs[$esc] = Cargar-Img $KyEscenas[$esc].Img }
    return $script:kyImgs[$esc]
}
# una escena llenando el hueco, con un zoom lento (como una cámara que respira)
function Ky-Dibujar-Escena($g, $esc, $alfa) {
    $img = Ky-Img $esc; if (-not $img) { return }
    $t = [Environment]::TickCount / 1000.0
    $z = 1.03 + 0.025 * [Math]::Sin($t / 6.0)
    $x0 = 404; $y0 = 56; $an = 352; $al = 222
    $w2 = $an * $z; $h2 = $al * $z; $dx = ($an - $w2) / 2 + [Math]::Sin($t / 9.0) * 3; $dy = ($al - $h2) / 2
    $dest = New-Object System.Drawing.RectangleF([float]($x0 + $dx), [float]($y0 + $dy), [float]$w2, [float]$h2)
    if ($alfa -ge 0.999) { $g.DrawImage($img, $dest) }
    else {
        $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$alfa
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle([int]$dest.X, [int]$dest.Y, [int]$dest.Width, [int]$dest.Height)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $ia.Dispose()
    }
}
# los detalles que se mueven en cada escena
function Ky-Ambiente($g, $esc) {
    $t = [Environment]::TickCount / 1000.0; $rn = New-Object System.Random 17
    switch ($esc) {
        'tranquilo' {   # motas de polvo flotando en la luz de la ventana
            for ($i = 0; $i -lt 18; $i++) { $px = 560 + $rn.Next(0, 190) + [Math]::Sin($t / 2.0 + $i) * 6; $py = 70 + (($rn.Next(0, 180) - $t * (4 + $i % 5)) % 180 + 180) % 180; $s = 1.5 + ($i % 3)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int](90 + 60 * [Math]::Sin($t + $i))) 255 244 220))), [float]$px, [float]$py, [float]$s, [float]$s) }
        }
        'solo' {   # la luz del portátil respira y cae un polvillo azul
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse(400, 150, 170, 130)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pg.CenterColor = (ARGB ([int](40 + 20 * [Math]::Sin($t * 1.3))) 180 210 255); $pg.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 180 210 255))
            $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose()
            for ($i = 0; $i -lt 12; $i++) { $px = 410 + $rn.Next(0, 340); $py = 60 + (($rn.Next(0, 210) + $t * (3 + $i % 4)) % 210); $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 70 170 200 255))), [float]$px, [float]$py, 2, 2) }
        }
        'cansado' {   # pétalos rosas que caen despacio
            for ($i = 0; $i -lt 10; $i++) { $px = 420 + $rn.Next(0, 320) + [Math]::Sin($t / 1.5 + $i) * 10; $py = 56 + (($rn.Next(0, 222) + $t * (6 + $i % 4)) % 222)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 110 245 170 180))), [float]$px, [float]$py, 5, 3) }
        }
        'agobiado' {   # humo que pasa por delante
            for ($i = 0; $i -lt 6; $i++) { $px = 404 + ((($rn.Next(0, 420) + $t * (10 + $i * 3)) % 460) - 60); $py = 120 + $rn.Next(0, 140) + [Math]::Sin($t / 2 + $i) * 8; $s = 60 + $rn.Next(0, 50)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 28 200 200 200))), [float]$px, [float]$py, [float]$s, [float]($s * 0.5)) }
        }
        'animado' {   # destellos del sol
            for ($i = 0; $i -lt 8; $i++) { $al = [int](60 + 80 * [Math]::Abs([Math]::Sin($t * 1.2 + $i))); $px = 410 + $rn.Next(0, 160); $py = 60 + $rn.Next(0, 90)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB $al 255 236 190))), [float]$px, [float]$py, 3, 3) }
        }
    }
}
function Ky-Pintar($g, $W, $H, $k) {
    Ky-Reset; $e = $script:ky; $ahora = [Environment]::TickCount
    $g.SetClip((New-Object System.Drawing.Rectangle(404, 56, 352, 222)))
    # la escena (con fundido desde la anterior) y lo que se mueve en ella
    $q = if ($e.Antes) { [Math]::Min(1.0, ($ahora - $e.CambioT) / [double]$KyTiempos.Fundido) } else { 1.0 }
    if ($q -lt 1.0 -and $e.Antes) { Ky-Dibujar-Escena $g $e.Antes 1.0; Ky-Dibujar-Escena $g $e.Escena $q }
    else { Ky-Dibujar-Escena $g $e.Escena 1.0 }
    Ky-Ambiente $g $e.Escena
    # la guitarra explota: destello y humo
    if ($e.Flash -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $e.Flash * 30), 255, 230, 160))), 404, 56, 352, 222) }
    if ($e.Fx -gt 0) {
        $rh = New-Object System.Random 4
        for ($i = 0; $i -lt 8; $i++) {
            $qq = 50 - $e.Fx; $hx = 470 + $rh.Next(0, 160); $hy = 260 - $qq * (1.5 + $rh.NextDouble()); $hr = 14 + $qq * 0.7
            if ($hy -gt 56) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int]([Math]::Min(1.0, $e.Fx / 20.0) * 120)) 80 70 70))), [float]($hx - $hr / 2), [float]$hy, [float]$hr, [float]$hr) }
        }
    }
    $g.ResetClip()
    # cómo está y qué suena (pegatina arriba a la izquierda de la escena)
    $txt = "Kenny está $($KyEscenas[$e.Escena].Nombre)"; $son = "♪ $($KyEscenas[$e.Escena].Cancion)"
    $f1 = FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold); $f2 = FntP('Segoe UI Symbol', 6.8)
    $tw = [Math]::Max($g.MeasureString($txt, $f1).Width, $g.MeasureString($son, $f2).Width) + 14
    $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 46 34 30))), (Ruta-Redonda 413 65 $tw 30 8))
    $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 235 255 248 240))), (Ruta-Redonda 410 62 $tw 30 8))
    $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 1.4)), (Ruta-Redonda 410 62 $tw 30 8))
    $g.DrawString($txt, $f1, (New-Object System.Drawing.SolidBrush((C 46 34 30))), 416, 64)
    $g.DrawString($son, $f2, (New-Object System.Drawing.SolidBrush((C 120 100 94))), 416, 77)
    # su ánimo, en pastillas marrones abajo
    $osc = (ARGB 235 80 60 54); $bl = [System.Drawing.Color]::White
    $barras = @(@('⚡', $e.Energia, (C 255 214 90), 20), @('♥', $e.Compania, (C 255 140 180), 116), @('☁', $e.Agobio, (C 170 180 200), 212))
    foreach ($b in $barras) {
        Yt-Pastilla $g $b[3] 280 92 24 $osc $null $null 9
        $g.DrawString($b[0], (FntP('Segoe UI Symbol', 9, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($b[2])), [float]($b[3] + 7), 283)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 100 94))), [float]($b[3] + 26), 289, 58, 6)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($b[2])), [float]($b[3] + 26), 289, [float](58 * $b[1] / 100.0), 6)
    }
    Yt-Pastilla $g 308 280 84 24 $osc $null $null 9
    if ($e.Escena -eq 'animado') {
        $g.DrawString('AMP', (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 314, 285)
        for ($i = 0; $i -lt 6; $i++) {
            $bh = 5 + $i * 1.8; $bx2 = 342 + $i * 7.5; $on = $e.Amp -ge ($i + 1) * 16.6 - 6
            $colA = if ($i -ge 4) { (C 255 60 60) } elseif ($i -ge 3) { (C 255 210 60) } else { (C 110 235 140) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($on) { $colA } else { (C 120 100 94) }))), [float]$bx2, [float](298 - $bh), 5, [float]$bh)
        }
    } else { $g.DrawString("⚡ rotas: $($e.Rotas)", (FntP('Segoe UI Symbol', 7.5, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 314, 285) }
}
# ¿está el ratón sobre la escena? (Kenny forma parte de la imagen)
function Ky-En-Escena {
    if (-not $script:skin -or $script:skin.Estilo -ne 'punk' -or (Ocupado)) { return $false }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    return ($x -ge 404 -and $x -le 756 -and $y -ge 96 -and $y -le 278)
}

# panel con el borde verde en zigzag de sus pegatinas
function Dibujar-Pegatina($g, $x, $y, $w, $h, $relleno) {
    $pts = New-Object System.Collections.ArrayList; $paso = 13; $sal = 7
    for ($i = 0; $i -le [int]($w / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x + $i * $paso), [float]($y - $o)))) }
    for ($i = 0; $i -le [int]($h / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x + $w + $o), [float]($y + $i * $paso)))) }
    for ($i = 0; $i -le [int]($w / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x + $w - $i * $paso), [float]($y + $h + $o)))) }
    for ($i = 0; $i -le [int]($h / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x - $o), [float]($y + $h - $i * $paso)))) }
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 120 110 235 140))), [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 3), ($_.Y + 3)) }))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 110 235 140))), [System.Drawing.PointF[]]$pts.ToArray())
    $r = Ruta-Redonda $x $y $w $h 10
    $g.FillPath((New-Object System.Drawing.SolidBrush($relleno)), $r); $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 2)), $r); $r.Dispose()
}
# los cuadros marrones de su camisa
function Dibujar-Cuadros($g, $x, $y, $w, $h) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 96 74 68))), $x, $y, $w, $h)
    $cl = New-Object System.Drawing.SolidBrush((ARGB 90 190 168 160)); $os = New-Object System.Drawing.Pen((ARGB 70 40 28 24), 2)
    for ($cy = $y + 4; $cy -lt $y + $h; $cy += 14) { for ($cx = $x + 4 + (($cy / 14) % 2) * 7; $cx -lt $x + $w; $cx += 14) { $g.FillRectangle($cl, [float]$cx, [float]$cy, 7, 7) } }
    for ($cx = $x; $cx -lt $x + $w; $cx += 28) { $g.DrawLine($os, [float]$cx, [float]$y, [float]$cx, [float]($y + $h)) }
    $cl.Dispose(); $os.Dispose()
}
# ================= ENFOSI: DEFIENDE LA ESTATUA =================
# Llegan Glaggles a la estatua. Algunos son Enphosians disfrazados con un fallo (piel de otro color,
# símbolo falso, sin símbolo o sin cara). Clic en el falso para descubrirlo y acabar con él.
# Clic en un inocente = strike. Con tres strikes viene el Ojo de Enphoso. Datos de las wikis del juego.
$script:ef = $null; $script:efImgs = @{}
function Enfosi-HPMax($ola) { if ($ola -ge 7) { return 10000 } elseif ($ola -ge 4) { return 7500 } else { return 5000 } }
function Enfosi-Reset {
    $script:ef = @{ Ola = 1; EnOla = 0; PorOla = 4; Strikes = 0; Puntos = 0; Bintar = 0; HP = 5000; HPMax = 5000; Errores = 0
        Ojo = 0; Sobber = $false; W = $null; Cola = 0; Auto = 0; Banner = $null; Cartel = $null; Siguiente = $null; Rojo = 0; Negro = 0; NX = 0; NY = 0 }
    $a = $script:actores['W']; if ($a) { $a.Visible = $false }
}
function Enfosi-Img($n) {
    if (-not $script:efImgs.ContainsKey($n)) { $script:efImgs[$n] = Cargar-Img "skins\enfosi\$n" }
    return $script:efImgs[$n]
}
function Enfosi-Pose($pose) {
    $a = $script:actores['W']; if (-not $a -or -not $a.Imgs[$pose]) { return }
    $a.Pose = $pose; $a.Base = $pose; $a.Hasta = 0; $a.Frame = 0; $a.Acc = 0; Seleccionar-Frame $a
}
function Enfosi-Cartel($img, $ticks, $siguiente) { $script:ef.Cartel = @{ Img = $img; T = $ticks; Max = $ticks }; $script:ef.Siguiente = $siguiente }
# un Glaggle nuevo empieza a caminar hacia la estatua
function Enfosi-Llega {
    $e = $script:ef; if (-not $e -or $e.W -or $e.Banner -or $e.Cartel) { return }
    $a = $script:actores['W']; if (-not $a) { return }
    $e.Auto = 0
    # el primero de cada oleada es siempre el Glaggle nuevo de esa oleada
    $tipo = if ($e.EnOla -eq 0) { $EnfosiTipos[$e.Ola - 1] } else { $EnfosiTipos[$Rnd.Next(0, $e.Ola)] }
    $falso = if ($Rnd.NextDouble() -lt 0.45) { $Rnd.Next(1, 5) } else { 0 }
    $e.W = @{ Tipo = $tipo; Falso = $falso; Estado = 'anda'; X = 700.0; Vida = $EnfosiVida[$tipo]; Atq = 0; Jefe = $false; Baile = 0 }
    $e.EnOla++
    Enfosi-Pose $(if ($falso) { "$tipo$falso" } else { $tipo })
    $a.Rect = @(700, 148, 74, 120); $a.Visible = $true; $a.Alfa = 1.0; $a.Baila = $false; $a.OY = 0
    Decir $EnfosiTexto[$tipo]
    Invalidar-Escena
}
function Enfosi-Jefe {
    $e = $script:ef; $a = $script:actores['W']; if (-not $a) { return }
    $j = $EnfosiJefes[$e.Ola]
    $e.W = @{ Tipo = $j[0]; Falso = 0; Estado = 'revelado'; X = 680.0; Vida = $j[2]; Atq = 0; Jefe = $true; Baile = 0 }
    Enfosi-Pose $j[0]
    $a.Rect = @(680, 118, 100, 150); $a.Visible = $true; $a.Alfa = 1.0; $a.Baila = $false
    Sonido 'alarma'; Sacudir $form 8
    Decir-Fijo $j[3]
}
function Enfosi-Clic($id) {
    $e = $script:ef; if (-not $e) { return }
    if ($id -eq 'E') {
        if (-not $e.W -and -not $e.Banner -and -not $e.Cartel) { Enfosi-Llega } else { Decir (Azar $script:skin.Clic) }
        return
    }
    $w = $e.W; if (-not $w) { return }
    $a = $script:actores['W']
    switch ($w.Estado) {
        'anda' {
            Sonido 'golpe'; if ($a) { $a.Temblor = 6 }
            if ($w.Falso -eq 0) { Enfosi-Strike } else { Enfosi-Revela 'golpe' }
        }
        { $_ -in @('revelado', 'ataca') } {
            $w.Vida--; Sonido 'golpe'; if ($a) { $a.Flash = 6; $a.Temblor = 6 }
            if ($w.Vida -le 0) { Enfosi-Muere }
        }
        'baila' { Decir '¡Déjalo! Está celebrando que ha llegado a la estatua.' }
    }
    $form.Invalidate()
}
function Enfosi-Strike {
    $e = $script:ef; $w = $e.W
    $e.Strikes++; $e.Errores++; $e.Puntos -= 100; $e.Rojo = 10
    Sonido 'buzzer'; Sacudir $form 8
    Flotante 'STRIKE' 470 120 (C 230 30 30) 30 'Arial Black'
    $w.Estado = 'muere'
    if ($e.Strikes -ge 3 -and $e.Ojo -eq 0 -and -not $e.Sobber) {
        $e.Ojo = 1; Sonido 'ojo'
        Decir-Fijo '¡Tres strikes! El Ojo de Enphoso viene a por ti. No se le puede hacer daño...'
    } else {
        Decir-Fijo "¡STRIKE! Era un $($EnfosiNombre[$w.Tipo]) inocente. *Suena un zumbido de error enorme.* (strike $($e.Strikes) de 3)"
    }
}
function Enfosi-Revela($como) {
    $e = $script:ef; $w = $e.W; $a = $script:actores['W']
    $w.Estado = if ($como -eq 'estatua') { 'ataca' } else { 'revelado' }
    Enfosi-Pose "$($w.Tipo)_e"
    Sonido 'revela'; Sacudir $form 6
    $e.Negro = 14; $e.NX = $w.X + 37; $e.NY = 200
    Flotante '¡ENPHOSIAN!' ($w.X - 40) 110 (C 20 20 20) 22 'Arial Black'
    if ($como -eq 'golpe') { Decir-Fijo "¡Era un Enphosian! El $($EnfosiNombre[$w.Tipo]) $($EnfosiFallo[$w.Falso]). ¡Acaba con él!" 1500 }
    else { Decir-Fijo "¡Un Enphosian ha llegado a la estatua! El $($EnfosiNombre[$w.Tipo]) $($EnfosiFallo[$w.Falso]). ¡Clic en él, rápido!" 1500 }
}
function Enfosi-Muere {
    $e = $script:ef; $w = $e.W
    $p = if ($w.Jefe) { 1000 } else { 200 }
    $e.Puntos += $p; Sonido 'ding'
    Flotante "+$p" ($w.X) 120 (C 255 214 60) 24 'Arial Black'
    $w.Estado = 'muere'
    if ($w.Jefe) { Decir-Fijo "¡Has derrotado a $($EnfosiNombre[$w.Tipo])! +1000 puntos." }
    else { Decir (Azar @('¡Enphosian eliminado! +200.', '¡Uno menos! La estatua está a salvo... de momento.', '¡Bien visto! Ese no era un Glaggle de verdad.')) }
}
function Enfosi-Fin-Glaggle {
    $e = $script:ef; $w = $e.W; $e.W = $null
    $a = $script:actores['W']; if ($a) { $a.Visible = $false; $a.Baila = $false }
    if ($w -and $w.Jefe) { Enfosi-Nueva-Ola; return }
    if ($e.EnOla -ge $e.PorOla) { Enfosi-Fin-Ola }
}
function Enfosi-Fin-Ola {
    $e = $script:ef
    $n = $e.Errores + $(if ($e.Sobber) { 3 } else { 0 })
    $r = @('glaggle', 'awesome', 'basic', 'coulddobetter', 'doingbad', 'enphosed')[[Math]::Min(5, $n)]
    $nom = @{ glaggle = 'GLAGGLE'; awesome = 'AWESOME'; basic = 'BASIC'; coulddobetter = 'COULD DO BETTER'; doingbad = 'DOING BAD'; enphosed = 'ENPHOSED' }[$r]
    $e.Bintar += 2; Sonido 'moneda'
    $sig = if ($e.Ola -in @(2, 4, 6)) { 'jefe' } else { 'ola' }
    Enfosi-Cartel "rango_$r.png" 60 $sig
    Decir-Fijo "¡Fin de la oleada $($e.Ola)! Rango: $nom. +2 Bintar."
}
function Enfosi-Nueva-Ola {
    $e = $script:ef
    if ($e.Ola -ge 7) {
        Decir-Fijo "¡Has sobrevivido a las 7 oleadas! Puntos: $($e.Puntos). La estatua sigue en pie. Volvemos a empezar."
        $b = $e.Bintar; Enfosi-Reset; $script:ef.Bintar = $b
    } else { $e.Ola++ }
    $e = $script:ef
    $e.EnOla = 0; $e.Strikes = 0; $e.Errores = 0; $e.Ojo = 0; $e.Sobber = $false
    $max = Enfosi-HPMax $e.Ola; if ($max -gt $e.HPMax) { $e.HPMax = $max; $e.HP = $max }
    $t = $EnfosiTipos[$e.Ola - 1]
    $e.Banner = @{ Img = "$($t)_oleada.png"; T = 55 }
    Sonido 'ola'
    if ($e.Ola -gt 1) { Decir-Fijo "Oleada $($e.Ola) de 7: ¡llegan los $($EnfosiNombre[$t])s!" 1000 }
}
function Enfosi-Derrota {
    $e = $script:ef
    Sonido 'revela'; Sacudir $form 14
    Enfosi-Cartel 'gameover.jpg' 70 'reset'
    Decir-Fijo "La estatua ha caído. ENPHOSED. Has llegado a la oleada $($e.Ola) con $($e.Puntos) puntos."
}
function Enfosi-Tick {
    $e = $script:ef; if (-not $e) { return }
    $a = $script:actores['W']; $est = $script:actores['E']
    if ($e.Rojo -gt 0) { $e.Rojo-- }
    if ($e.Negro -gt 0) { $e.Negro-- }
    if ($e.Banner) { $e.Banner.T--; if ($e.Banner.T -le 0) { $e.Banner = $null } }
    if ($e.Cartel) {
        $e.Cartel.T--
        if ($e.Cartel.T -le 0) {
            $e.Cartel = $null; $s = $e.Siguiente; $e.Siguiente = $null
            switch ($s) { 'jefe' { Enfosi-Jefe } 'ola' { Enfosi-Nueva-Ola } 'reset' { $b = $e.Bintar; Enfosi-Reset; $script:ef.Bintar = $b; $script:ef.Banner = @{ Img = 'giggler_oleada.png'; T = 55 }; Sonido 'ola' } }
        }
    }
    $e = $script:ef
    # el Ojo de Enphoso se acerca; si llega, te convierte en Sobber
    if ($e.Ojo -gt 0) {
        $e.Ojo++
        if ($e.Ojo -ge 170) {
            $e.Ojo = 0; $e.Sobber = $true; $e.Rojo = 14; Sonido 'revela'; Sacudir $form 12
            Enfosi-Cartel 'gameover.jpg' 30 $null
            Decir-Fijo 'El Ojo de Enphoso te ha atrapado. Ahora eres un Sobber hasta que acabe la oleada.'
        }
    }
    # un Glaggle de vez en cuando aunque no abras nada (cada 25 s)
    if (-not $e.W -and -not $e.Banner -and -not $e.Cartel) {
        if ($e.Cola -gt 0) { $e.Cola--; Enfosi-Llega } else { $e.Auto++; if ($e.Auto -ge 500) { Enfosi-Llega } }
    }
    $w = $e.W
    if ($w -and $a) {
        $vel = if ($w.Jefe) { 0.9 } else { $EnfosiVel[$w.Tipo] }
        switch ($w.Estado) {
            'anda' {
                $w.X -= $vel
                if ($w.X -le 528) {
                    $w.X = 528
                    if ($w.Falso -gt 0) { Enfosi-Revela 'estatua' }
                    else { $w.Estado = 'baila'; $w.Baile = 34; $a.Baila = $true; Decir (Azar @('*El Glaggle llega a la estatua y baila. ¡Yeah!*', '¡Un inocente ha llegado sano y salvo! *Baila de alegría.*', '*Baila delante de la estatua... y explota en confeti.* ¡Era de los buenos!')) }
                }
            }
            'revelado' {
                $w.X -= $vel * $(if ($w.Tipo -eq 'cheerer') { 2.2 } else { 1.5 })
                if ($w.X -le 528) { $w.X = 528; $w.Estado = 'ataca' }
            }
            'ataca' {
                $w.Atq++
                if ($w.Atq % 20 -eq 1) {
                    $d = if ($w.Jefe) { 300 } else { $EnfosiDanio[$w.Tipo] }
                    $e.HP -= $d; $e.Errores = [Math]::Max($e.Errores, 1); Sonido 'estatua'
                    if ($est) { $est.Temblor = 8; $est.Flash = 4 }
                    Flotante "-$d" 440 110 (C 230 30 30) 22 'Arial Black'
                    # el Cheerer falso explota contra la estatua (y desaparece)
                    if ($w.Tipo -eq 'cheerer' -and -not $w.Jefe) { $e.Negro = 16; $e.NX = 520; $e.NY = 200; Sacudir $form 12; $w.Estado = 'muere'; $a.Alfa = 0.2 }
                    if ($e.HP -le 0) { $e.HP = 0; $e.W = $null; $a.Visible = $false; Enfosi-Derrota; return }
                }
            }
            'baila' {
                $w.Baile--
                if ($w.Baile -le 0) {
                    Sonido 'confeti'; $e.Puntos += 50
                    foreach ($i in 0..4) { Flotante (Azar @('✦', '★', '●')) ($w.X + $Rnd.Next(-10, 60)) (140 + $Rnd.Next(0, 60)) (@((C 255 214 60), (C 255 90 160), (C 90 200 255), (C 120 230 90), (C 255 255 255))[$i]) 18 'Segoe UI Symbol' }
                    Enfosi-Fin-Glaggle; Invalidar-Escena; return
                }
            }
            'muere' {
                $a.Alfa = [Math]::Max(0.0, $a.Alfa - 0.1)
                if ($a.Alfa -le 0) { Enfosi-Fin-Glaggle; Invalidar-Escena; return }
            }
        }
        $a.Rect = @([int]$w.X, $a.Rect[1], $a.Rect[2], $a.Rect[3])
    }
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](276 * $script:K), [int](410 * $script:K), [int](44 * $script:K))))
}
# carita de las vidas (como la barra de strikes del juego)
function Dibujar-Carita($g, $x, $y, $r, $bien) {
    if ($bien) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 214 60))), [float]($x - $r), [float]($y - $r), [float](2 * $r), [float](2 * $r))
        $p = New-Object System.Drawing.Pen((C 30 30 30), 1.6); $g.DrawEllipse($p, [float]($x - $r), [float]($y - $r), [float](2 * $r), [float](2 * $r))
        $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($x - $r * 0.4), [float]($y - $r * 0.45), [float]($r * 0.22), [float]($r * 0.42))
        $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($x + $r * 0.18), [float]($y - $r * 0.45), [float]($r * 0.22), [float]($r * 0.42))
        $g.DrawArc($p, [float]($x - $r * 0.6), [float]($y - $r * 0.55), [float]($r * 1.2), [float]($r * 1.1), 20, 140); $p.Dispose()
    } else {
        $p = New-Object System.Drawing.Pen((C 230 30 30), 3.5); $p.StartCap = 'Round'; $p.EndCap = 'Round'
        $g.DrawLine($p, [float]($x - $r * 0.8), [float]($y - $r * 0.8), [float]($x + $r * 0.8), [float]($y + $r * 0.8)); $g.DrawLine($p, [float]($x + $r * 0.8), [float]($y - $r * 0.8), [float]($x - $r * 0.8), [float]($y + $r * 0.8)); $p.Dispose()
    }
}

# ================= NANACHI (Made in Abyss): ESTOFADO DEL ABISMO Y MULLIDO =================
# Cada app echa un ingrediente a la olla; con 5, sirve un estofado del Abismo (cada vez le sale un poco mejor).
# Clic en Nanachi: le acaricias. El medidor MULLIDO sube; si le tocas mucho seguido, se incomoda y se aparta.
# Su "dibujo" de la pared enseña su cara del anime según lo que pase. Por el fondo suben los hilos del campo de fuerza.
$script:nn = $null
function Nn-Reset { if (-not $script:nn) { $script:nn = @{ Ing = 0; Estofados = 0; Mullido = 0.0; Toques = 0.0; Cara = $null; CaraHasta = 0; Fx = 0; Vapor = 0 } } }
$script:nnCaras = @{}
function Nn-Gif($n) {
    if (-not $script:nnCaras.ContainsKey($n)) {
        $r = $script:skin.Caritas[$n]; $img = if ($r) { Cargar-Img $r } else { $null }
        $script:nnCaras[$n] = if ($img) { @{ Img = $img; Info = (Gif-Info $img) } } else { $null }
    }
    return $script:nnCaras[$n]
}
function Nn-Liberar { foreach ($c in @($script:nnCaras.Values)) { if ($c) { $c.Img.Dispose() } }; $script:nnCaras = @{} }
# pone una cara en su dibujo de la pared durante un rato
function Nn-Cara($n, $ms) { Nn-Reset; $script:nn.Cara = $n; $script:nn.CaraHasta = [Environment]::TickCount + $ms }
function Nn-App($linea) {
    Nn-Reset; $e = $script:nn; $k = $script:skin
    $ing = $k.Ingredientes[$e.Ing % $k.Ingredientes.Count]; $e.Ing++
    Sonido 'plof'; $e.Vapor = 30
    Flotante '+1' 470 190 (C 236 170 190) 18 'Georgia'
    if ($e.Ing -ge $k.Ingredientes.Count) {
        # olla llena: se sirve el estofado (y cada vez le sale un poco menos horrible)
        $e.Ing = 0; $e.Estofados++; Sonido 'sorbo'; Nn-Cara 'mastica' 3500
        $n = $e.Estofados
        $txt = if ($n -le 2) { Azar @('Estofado del Abismo. Sabe fatal. Me da igual. Cómetelo.', '*Te pone un cuenco de algo marrón delante sin mirarte.* Nutritivo. Asqueroso. Ambas cosas.', 'Listo. Textura de barro. Si no te gusta, no lo comas. A mí me da lo mismo.') }
               elseif ($n -le 5) { Azar @('Estofado número ' + $n + '. Esta vez he quitado las espinas. Algunas.', '*Lo prueba primero.* ...mejor que el anterior. Que no es decir mucho. Nnaa.', 'Riko me enseñó a no hervirlo de golpe. Ahora solo sabe un poco a pescado.') }
               else { Azar @('Estofado número ' + $n + '. Está... bueno. ¿Está bueno? *Lo vuelve a probar.* Nnaa~ ¡Está bueno!', 'He aprendido a cocinar de verdad. Para cuando vuelva a ver a alguien especial. Toma, pruébalo tú primero.', 'Mira cómo brilla el caldo. Esto ya no es estofado del Abismo. Es estofado de Nanachi.') }
        Decir-Fijo $txt 'abiertos'
    } else {
        Nn-Cara $(if ($Rnd.Next(2) -eq 0) { 'chulo' } else { 'sentado' }) 3000
        Decir "$linea (A la olla, $ing. Por echar algo.)"
    }
    $form.Invalidate()
}
function Nn-Clic {
    Nn-Reset; $e = $script:nn; $k = $script:skin
    $e.Toques += 1.0; $e.Mullido = [Math]::Min(100.0, $e.Mullido + 9.0)
    Sonido 'brillo'
    foreach ($i in 0..1) { Flotante (Azar @('✿', '♥', '✦')) (610 + $Rnd.Next(0, 110)) (90 + $Rnd.Next(0, 90)) (@((C 236 170 190), (C 252 240 214), (C 190 230 170))[$Rnd.Next(3)]) 20 'Segoe UI Symbol' }
    if ($e.Mullido -ge 100.0) {
        $e.Mullido = 40.0; $e.Toques = 0.0; $e.Fx = 40; Nn-Cara 'feliz' 6000
        Decir-Fijo (Azar $k.MullidoMax) 'abiertos'
    } elseif ($e.Toques -ge 4.0) {
        $e.Toques = 2.0; Nn-Cara 'tapa' 3000
        $a = $script:actores['N']; if ($a) { $a.Dash = 14 }
        Decir (Azar $k.Mimos3)
    } elseif ($e.Toques -ge 2.0) {
        Nn-Cara 'verguenza' 2500; Decir (Azar $k.Mimos2)
    } else {
        Nn-Cara $(if ($Rnd.Next(2) -eq 0) { 'mimos' } else { 'ronroneo' }) 3000; Decir (Azar $k.Mimos1)
    }
    $form.Invalidate()
}
function Nn-Mitty {
    Nn-Reset; $k = $script:skin
    Sonido 'brillo'; Nn-Cara 'feliz' 3500
    $a = $script:actores['M']; if ($a) { $a.Salto = 10 }
    foreach ($i in 0..2) { Flotante '♥' (530 + $Rnd.Next(0, 80)) (178 + $Rnd.Next(0, 20)) (C 236 170 190) 18 'Segoe UI Symbol' }
    Decir (Azar $k.Mitty) 'abiertos'
    $form.Invalidate()
}
function Nn-Tick {
    Nn-Reset; $e = $script:nn
    # los toques se olvidan solos (unos 2,5 s cada uno) y el medidor baja muy despacio
    if ($e.Toques -gt 0.0) { $e.Toques = [Math]::Max(0.0, $e.Toques - 0.02) }
    if ($e.Mullido -gt 0.0) { $e.Mullido = [Math]::Max(0.0, $e.Mullido - 0.03) }
    if ($e.Fx -gt 0) { $e.Fx-- }
    if ($e.Vapor -gt 0) { $e.Vapor-- }
    # el dibujo de la pared, los hilos del campo de fuerza y el vapor siempre se mueven
    $Z = $script:K
    $form.Invalidate((New-Object System.Drawing.Rectangle([int](406 * $Z), [int](56 * $Z), [int](354 * $Z), [int](222 * $Z))))
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](410 * $Z), [int](50 * $Z))))
}
# silbato de explorador (los rangos del Abismo): rojo, azul, luna, negro y blanco
function Dibujar-Silbato($g, $x, $y, $col) {
    $g.FillPath((New-Object System.Drawing.SolidBrush($col)), (Ruta-Redonda $x $y 8 18 4))
    $g.DrawPath((New-Object System.Drawing.Pen((C 40 30 24), 1.2)), (Ruta-Redonda $x $y 8 18 4))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 30 24))), [float]($x + 2), [float]($y + 3), 4, 4)
    $g.DrawLine((New-Object System.Drawing.Pen((C 120 96 70), 1)), [float]($x + 4), [float]$y, [float]($x + 4), [float]($y - 8))
}
# el muñeco de pájaro que Nanachi cosió para Mitty (tela verde y rosa)
function Dibujar-Muneco($g, $x, $y) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), [float]($x - 2), [float]($y + 26), 40, 8)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 96 150 96))), [float]$x, [float]$y, 36, 30)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 236 170 190))), [float]($x + 8), [float]($y + 12), 20, 16)
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 230 200 120))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 32), [float]($y + 10))), (New-Object System.Drawing.PointF([float]($x + 44), [float]($y + 13))), (New-Object System.Drawing.PointF([float]($x + 32), [float]($y + 16)))))
    $g.FillEllipse([System.Drawing.Brushes]::White, [float]($x + 24), [float]($y + 6), 6, 6); $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($x + 26), [float]($y + 8), 3, 3)
    $pc = New-Object System.Drawing.Pen((C 60 44 34), 1); $pc.DashStyle = 'Dash'; $g.DrawEllipse($pc, [float]$x, [float]$y, 36, 30); $pc.Dispose()
}
# los hilos del campo de fuerza que solo ve Nanachi: líneas suaves que suben despacio
function Dibujar-Campo($g, $x0, $y0, $w, $h, $alfa) {
    $t = [Environment]::TickCount / 1000.0
    for ($i = 0; $i -lt 7; $i++) {
        $bx = $x0 + 20 + $i * ($w - 40) / 6.0
        $pts = New-Object System.Collections.ArrayList
        for ($yy = 0; $yy -le $h; $yy += 12) { [void]$pts.Add((New-Object System.Drawing.PointF([float]($bx + [Math]::Sin(($yy + $t * 40 + $i * 37) / 34.0) * 9), [float]($y0 + $h - $yy)))) }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alfa, 210, 255, 220), 1.4)
        $g.DrawCurve($pen, [System.Drawing.PointF[]]$pts.ToArray()); $pen.Dispose()
        # chispitas que suben por cada hilo
        $py = $y0 + $h - (($t * 22 + $i * 41) % $h)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $alfa * 3), 230, 255, 235))), [float]($bx + [Math]::Sin(($h - $py + $y0 + $t * 40 + $i * 37) / 34.0) * 9 - 2), [float]($py - 2), 4, 4)
    }
}

# ================= WEATHERGIRL (FLAVOR FOLEY ft. Eleanor Forte): EL PARTE DEL TIEMPO =================
# Eleanor Forte presenta el parte del tiempo en directo. EL TIEMPO ES EL DE VERDAD: se pide a wttr.in sin bloquear el
# panel (DownloadStringTaskAsync; en cada tick se mira si ha llegado). Sin conexión, se lo inventa (y lo dice).
# La escena (cielo, nubes, sol o luna, edificios) cambia con el tiempo: sol, nubes, lluvia, tormenta, nieve o niebla,
# y de noche se oscurece. Cuando cambia, se vuelve a pintar el fondo guardado ($script:bmpEscena).
# PALABRAS SIN DECIR (0-6, "all the words I left unsaid"): cada app abierta es algo que se calla (da el parte en su
# lugar). 3 clics seguidos en ella: dice algo sincero y se le quitan 2. Al llegar a 6 se echa a LLORAR: tormenta en el
# plató, truenos, lágrimas y AVISO ROJO. Con 3 clics la consuelas y salen los CIELOS VIVOS (sol y arcoíris un rato);
# si nadie la consuela, se calma sola y vuelve el tiempo real. Si llueve, en la escena aparece un paraguas: clic y se
# lo das (rice: "se me olvidó el paraguas...").
$WgTiempos = @{ PalabrasMax = 6; Sincera = 3; Consuelo = 3; Tormenta = 45000; Vivos = 90000; Paraguas = 180000; Consulta = 1800000; Espera = 15000; ClicReset = 6000 }
# la intro son dos trozos del videoclip: 0-4,5 s y luego 153-169,5 s (el titular y la tele con "weathergirl").
# La instrumental oficial va 60 ms por detrás del vídeo (medido comparando las dos pistas).
$WgIntro = @{ CorteMs = 4500; SegundoDesde = 153000; Desfase = 60 }
# la tarjeta del tiempo (arriba a la izquierda de la escena) y el botón del paraguas (debajo)
$WgTarjeta = @(412, 62, 122, 138)
$WgParaguasBtn = @(412, 206, 122, 26)
# los ojos de Eleanor dentro de su dibujo (en proporción del dibujo), para las lágrimas
$WgOjos = @(@(0.393, 0.25), @(0.538, 0.238))
$WgNombres = @{ sol = 'Despejado'; nubes = 'Nublado'; lluvia = 'Lluvia'; tormenta = 'Tormenta'; nieve = 'Nieve'; niebla = 'Niebla'; vivos = 'Cielos vivos' }
$script:wg = $null; $script:wgMusica = $null; $script:wgIntroAudio = $null
function Wg-Reset {
    if (-not $script:wg) {
        $script:wg = @{ Cielo = 'nubes'; Real = $false; Temp = 15; Desc = 'Nublado'; Lugar = ''; Max = 17; Min = 10; MDesc = 'Nublado'; MCielo = 'nubes'
            Pedido = $null; PedidoT = 0; Consulta = 0; Avisado = $false; Palabras = 0; Clics = 0; ClicT = 0; Tormenta = 0; Consuelo = 0; Vivos = 0; Paraguas = 0
            Rayo = 0; RayoX = 600; TruenoT = 0; Ticker = 'EN DIRECTO · EL PARTE DEL TIEMPO CON ELEANOR FORTE'; TickerX = 0.0; TickerW = 400.0; Fx = 0
            Gotas = (New-Object System.Collections.ArrayList); Lagrimas = (New-Object System.Collections.ArrayList); Letras = (New-Object System.Collections.ArrayList); LetraT = 0; Pintado = '' }
    }
}
function Wg-Llora { return ($script:wg -and [Environment]::TickCount -lt $script:wg.Tormenta) }
function Wg-Noche { $hora = (Get-Date).Hour; return ($hora -ge 21 -or $hora -lt 7) }
# el cielo que se ve: la tormenta de llorar y los cielos vivos mandan sobre el tiempo de verdad
function Wg-Cielo {
    $e = $script:wg; if (-not $e) { return 'nubes' }
    $ahora = [Environment]::TickCount
    if ($ahora -lt $e.Tormenta) { return 'tormenta' }
    if ($ahora -lt $e.Vivos) { return 'vivos' }
    return $e.Cielo
}
# código del tiempo de wttr.in (los de WorldWeatherOnline) -> cielo de la escena
function Wg-Codigo($c) {
    if ($c -eq 113) { return 'sol' }
    if ($c -in @(116, 119, 122)) { return 'nubes' }
    if ($c -in @(143, 248, 260)) { return 'niebla' }
    if ($c -in @(200, 386, 389, 392, 395)) { return 'tormenta' }
    if ($c -in @(179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377)) { return 'nieve' }
    return 'lluvia'
}
function Wg-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.5 * $script:aj.Volumen / 100.0)) }
function Wg-Musica-On($desdeMs) {
    if (-not $script:aj.Sonido -or $script:wgMusica) { return }
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta 'skins\weathergirl\cancion.mp3')); $mp.Volume = (Wg-Volumen)
        $script:wgDesde = 0
        if ($desdeMs -gt 0) { $mp.Position = [TimeSpan]::FromMilliseconds($desdeMs); $script:wgDesde = [double]$desdeMs; $script:wgDesdeT = [Environment]::TickCount }
        $mp.Play()
        $script:wgMusica = $mp
    } catch { $script:wgMusica = $null }
}
function Wg-Musica-Off {
    if ($script:wgMusica) { try { $script:wgMusica.Stop(); $script:wgMusica.Close() } catch {}; $script:wgMusica = $null }
}
# pide el tiempo de verdad a wttr.in (por la conexión: no hace falta decir dónde estás)
function Wg-Pedir {
    $e = $script:wg; if ($e.Pedido) { return }
    $e.Consulta = [Environment]::TickCount
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Encoding = [System.Text.Encoding]::UTF8
        $wc.Headers.Add('User-Agent', 'curl/8.4.0')
        $e.Pedido = $wc.DownloadStringTaskAsync('https://wttr.in/?format=j1&lang=es')
        $e.PedidoT = [Environment]::TickCount
    } catch { $e.Pedido = $null; if (-not $e.Real) { Wg-Inventar } }
}
# ¿ha llegado la respuesta? (se mira en cada tick, sin esperar)
function Wg-Revisar {
    $e = $script:wg; $t = $e.Pedido
    if (-not $t) { return }
    if (-not $t.IsCompleted) {
        if ([Environment]::TickCount - $e.PedidoT -gt $WgTiempos.Espera) { $e.Pedido = $null; if (-not $e.Real) { Wg-Inventar }; Wg-Primer-Parte }
        return
    }
    $e.Pedido = $null
    $ok = $false
    if ($t.Status -eq 'RanToCompletion') {
        try {
            $j = $t.Result | ConvertFrom-Json
            $cc = @($j.current_condition)[0]
            $e.Temp = [int]$cc.temp_C
            $e.Cielo = Wg-Codigo ([int]$cc.weatherCode)
            $d = if ($cc.lang_es) { [string]@($cc.lang_es)[0].value } else { '' }
            $e.Desc = if ($d.Trim()) { $d.Trim() } else { $WgNombres[$e.Cielo] }
            $ar = @($j.nearest_area)[0]; $e.Lugar = [string]@($ar.areaName)[0].value
            $dias = @($j.weather)
            if ($dias.Count -ge 2) {
                $mn = $dias[1]; $e.Max = [int]$mn.maxtempC; $e.Min = [int]$mn.mintempC
                $hr = @($mn.hourly); $h4 = $hr[[Math]::Min(4, $hr.Count - 1)]
                $e.MCielo = Wg-Codigo ([int]$h4.weatherCode)
                $md = if ($h4.lang_es) { [string]@($h4.lang_es)[0].value } else { '' }
                $e.MDesc = if ($md.Trim()) { $md.Trim() } else { $WgNombres[$e.MCielo] }
            }
            $e.Real = $true; $ok = $true
        } catch { $ok = $false }
    }
    if (-not $ok -and -not $e.Real) { Wg-Inventar }
    Wg-Primer-Parte
}
# la primera vez que tiene el tiempo (de verdad o inventado), lo dice
function Wg-Primer-Parte {
    $e = $script:wg
    if ($e.Avisado -or (Ocupado) -or -not $script:skin -or $script:skin.Estilo -ne 'clima') { return }
    $e.Avisado = $true; Wg-Parte
}
# sin conexión: un tiempo creíble, y ella avisa de que es a ojo
function Wg-Inventar {
    $e = $script:wg
    $c = Azar @('nubes', 'nubes', 'nubes', 'lluvia', 'lluvia', 'lluvia', 'sol', 'sol', 'niebla', 'tormenta')
    $e.Cielo = $c; $e.Desc = $WgNombres[$c]; $e.Temp = $Rnd.Next(8, 25); $e.Lugar = ''
    $e.MCielo = Azar @('nubes', 'lluvia', 'sol'); $e.MDesc = $WgNombres[$e.MCielo]
    $e.Min = $e.Temp - $Rnd.Next(2, 6); $e.Max = $e.Temp + $Rnd.Next(1, 5)
    $e.Real = $false
}
function Wg-Ticker($txt) { $script:wg.Ticker = $txt; $script:wg.TickerX = 0.0 }
function Wg-Parte {
    Wg-Reset; $e = $script:wg; $k = $script:skin
    $lugar = if ($e.Lugar) { $e.Lugar } else { 'tu zona' }
    Sonido 'noticia'
    Wg-Ticker ('EL TIEMPO · {0}: {1}, {2}° · MAÑANA: {3}, DE {4}° A {5}°' -f $lugar.ToUpper(), $e.Desc.ToUpper(), $e.Temp, $e.MDesc.ToUpper(), $e.Min, $e.Max)
    if ($e.Real) { Decir ((Azar $k.Pronostico) -f $e.Desc.ToLower(), $e.Temp, $lugar) }
    else { Decir ((Azar $k.PronosticoInventado) -f $e.Desc.ToLower(), $e.Temp) }
}
function Wg-Manana {
    Wg-Reset; $e = $script:wg
    Decir ((Azar $script:skin.Manana) -f $e.MDesc.ToLower(), $e.Min, $e.Max)
}
# cada app: sale en el rótulo de última hora y es una palabra más que se queda sin decir
function Wg-App($linea, $nombre) {
    Wg-Reset; $e = $script:wg; $k = $script:skin
    Sonido 'tele'
    if (Wg-Llora) { Wg-Ticker ('AVISO ROJO · SE ABRE {0} ENTRE LÁGRIMAS · {1}' -f $nombre.ToUpper(), (Azar $k.TitularesTormenta)); Decir (Azar $k.LloraApp); return }
    Wg-Ticker ('ÚLTIMA HORA · SE ABRE {0} · {1}' -f $nombre.ToUpper(), (Azar $k.Titulares))
    $e.Palabras = [Math]::Min($WgTiempos.PalabrasMax, $e.Palabras + 1)
    if ($e.Palabras -ge $WgTiempos.PalabrasMax) { Wg-Tormenta; return }
    if ($e.Palabras -ge 4 -and $Rnd.Next(100) -lt 45) { Decir ((Azar $k.Callada) -f $nombre); return }
    if ($Rnd.Next(100) -lt 50) { Decir ((Azar $k.AppTiempo) -f $nombre); return }
    Decir $linea
}
# se le junta todo y llora: tormenta en el plató
function Wg-Tormenta {
    $e = $script:wg; $k = $script:skin
    $e.Tormenta = [Environment]::TickCount + $WgTiempos.Tormenta; $e.Consuelo = 0; $e.Vivos = 0
    $e.TruenoT = [Environment]::TickCount + 4000
    Wg-Rayo
    Wg-Ticker ('AVISO ROJO · TORMENTA EN EL PLATÓ · ' + (Azar $k.TitularesTormenta))
    Decir-Fijo (Azar $k.Tormenta)
}
function Wg-Rayo {
    $e = $script:wg; Sonido 'trueno'
    if (-not $script:aj.Epilepsia) { $e.Rayo = 6 }
    $e.RayoX = 430 + $Rnd.Next(0, 300)
}
function Wg-Clic {
    Wg-Reset; $e = $script:wg; $k = $script:skin; $ahora = [Environment]::TickCount
    if (Wg-Llora) {
        # consolarla
        $e.Consuelo++
        Flotante '♥' (600 + $Rnd.Next(0, 90)) (110 + $Rnd.Next(0, 60)) (C 150 190 255) 20 'Segoe UI Symbol'
        if ($e.Consuelo -ge $WgTiempos.Consuelo) { Wg-Vivos; return }
        Decir (Azar $k.Consuelo); return
    }
    if ($ahora - $e.ClicT -gt $WgTiempos.ClicReset) { $e.Clics = 0 }
    $e.ClicT = $ahora; $e.Clics++
    if ($e.Clics -ge $WgTiempos.Sincera) {
        # la miras de verdad: se atreve a decir algo
        $e.Clics = 0; $e.Palabras = [Math]::Max(0, $e.Palabras - 2)
        Flotante '♥' 640 120 (C 120 160 255) 22 'Segoe UI Symbol'
        Decir-Fijo (Azar $k.Sincera); return
    }
    Decir (Azar $k.Clic)
}
# después de llorar, se abre el cielo
function Wg-Vivos {
    $e = $script:wg; $k = $script:skin
    $e.Tormenta = 0; $e.Consuelo = 0; $e.Palabras = 0; $e.Lagrimas.Clear()
    $e.Vivos = [Environment]::TickCount + $WgTiempos.Vivos
    if (-not $script:aj.Epilepsia) { $e.Fx = 20 }
    Sonido 'sol'
    Wg-Ticker ('ÚLTIMA HORA · CIELOS VIVOS EN TODA LA REGIÓN · ' + (Azar $k.TitularesSol))
    Wg-Letra 'vivid skies'; Wg-Letra 'trust the sky'
    Decir-Fijo (Azar $k.CielosVivos)
}
function Wg-Letra($txt) {
    [void]$script:wg.Letras.Add(@{ Txt = $txt; X = [double]$Rnd.Next(420, 640); Y = [double]$Rnd.Next(66, 236); T = 0; Vida = 96; Tam = 10 + $Rnd.Next(0, 6) })
}
# el paraguas: se ve en la escena cuando llueve y ella no tiene
function Wg-Paraguas-Visible {
    $e = $script:wg; if (-not $e) { return $false }
    $c = Wg-Cielo
    return (($c -eq 'lluvia' -or $c -eq 'tormenta') -and [Environment]::TickCount -ge $e.Paraguas)
}
function Wg-Paraguas-En-Raton {
    if (-not $script:skin -or $script:skin.Estilo -ne 'clima' -or (Ocupado) -or -not (Wg-Paraguas-Visible)) { return $false }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K; $r = $WgParaguasBtn
    return ($x -ge $r[0] -and $x -le $r[0] + $r[2] -and $y -ge $r[1] -and $y -le $r[1] + $r[3])
}
function Wg-Dar-Paraguas {
    $e = $script:wg; $e.Paraguas = [Environment]::TickCount + $WgTiempos.Paraguas
    Sonido 'paraguas'; Decir (Azar $script:skin.Paraguas)
}
function Wg-Tick {
    Wg-Reset; $e = $script:wg; $k = $script:skin; $ahora = [Environment]::TickCount
    # la instrumental: durante la intro suena el audio del vídeo; luego se repite, sigue el volumen y se calla sin sonido
    if ($script:transicion -and $script:wgIntroAudio) { }
    elseif (-not $script:aj.Sonido) { Wg-Musica-Off }
    elseif (-not $script:wgMusica) { Wg-Musica-On }
    else {
        try {
            $mp = $script:wgMusica
            if ([Math]::Abs($mp.Volume - (Wg-Volumen)) -gt 0.01) { $mp.Volume = (Wg-Volumen) }
            # el mp3 tarda un poco en abrirse y arranca retrasado: los primeros 3 s se recoloca si se desvía
            if ($script:wgDesde -gt 0) {
                $pasado = $ahora - $script:wgDesdeT
                if ($pasado -gt 3000) { $script:wgDesde = 0 }
                elseif ($mp.NaturalDuration.HasTimeSpan) {
                    $quiero = $script:wgDesde + $pasado
                    if ([Math]::Abs($mp.Position.TotalMilliseconds - $quiero) -gt 200.0) { $mp.Position = [TimeSpan]::FromMilliseconds($quiero) }
                }
            }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # el tiempo de verdad: al empezar y cada media hora
    if (-not $e.Pedido -and ($e.Consulta -eq 0 -or $ahora - $e.Consulta -gt $WgTiempos.Consulta)) { Wg-Pedir }
    Wg-Revisar
    if (-not $e.Avisado -and -not $e.Pedido -and $e.Consulta -ne 0) { Wg-Primer-Parte }
    # la tormenta de llorar: truenos de vez en cuando; si nadie la consuela, se calma sola
    if ($e.Tormenta -ne 0) {
        if ($ahora -ge $e.Tormenta) { $e.Tormenta = 0; $e.Palabras = 3; $e.Lagrimas.Clear(); if (-not (Ocupado)) { Decir (Azar $k.SeCalma) } }
        elseif ($ahora -ge $e.TruenoT) { Wg-Rayo; $e.TruenoT = $ahora + 5000 + $Rnd.Next(0, 5000) }
    }
    elseif ($e.Cielo -eq 'tormenta' -and $ahora -ge $e.Vivos -and $Rnd.Next(500) -eq 0) { Wg-Rayo }
    if ($e.Vivos -ne 0 -and $ahora -ge $e.Vivos) { $e.Vivos = 0; if (-not (Ocupado)) { Decir (Azar $k.SeNubla) } }
    if ($e.Rayo -gt 0) { $e.Rayo-- }
    if ($e.Fx -gt 0) { $e.Fx-- }
    # si el cielo ha cambiado, se vuelve a pintar el fondo
    $cielo = Wg-Cielo; $clave = "$cielo|$(Wg-Noche)"
    if ($e.Pintado -ne $clave) {
        $e.Pintado = $clave
        if ($script:bmpEscena) { $script:bmpEscena.Dispose(); $script:bmpEscena = $null }
        $form.Invalidate()
    }
    # lluvia o nieve
    $n = switch ($cielo) { 'lluvia' { 70 } 'tormenta' { 120 } 'nieve' { 50 } default { 0 } }
    while ($e.Gotas.Count -lt $n) { [void]$e.Gotas.Add(@{ X = [double]$Rnd.Next(404, 790); Y = [double]$Rnd.Next(30, 276); V = 7.0 + $Rnd.NextDouble() * 5; L = 8 + $Rnd.Next(0, 10) }) }
    while ($e.Gotas.Count -gt $n) { $e.Gotas.RemoveAt($e.Gotas.Count - 1) }
    $viento = if ($cielo -eq 'tormenta') { -4.0 } else { -1.8 }
    foreach ($d in $e.Gotas) {
        if ($cielo -eq 'nieve') { $d.Y += $d.V * 0.16; $d.X += [Math]::Sin($ahora / 700.0 + $d.L) * 0.5 }
        else { $d.Y += $d.V; $d.X += $viento * $d.V / 9.0 }
        if ($d.Y -gt 278) { $d.Y = 40.0 - $Rnd.Next(0, 30); $d.X = [double]$Rnd.Next(404, 800) }
        if ($d.X -lt 404) { $d.X += 380 }
    }
    # lágrimas
    if (Wg-Llora) {
        if ($Rnd.Next(3) -eq 0) { $o = $WgOjos[$Rnd.Next(2)]; [void]$e.Lagrimas.Add(@{ FX = $o[0] + ($Rnd.NextDouble() - 0.5) * 0.04; FY = $o[1] + 0.035; D = 0.0 }) }
    }
    for ($i = $e.Lagrimas.Count - 1; $i -ge 0; $i--) { $l = $e.Lagrimas[$i]; $l.D += 0.011; if ($l.D -gt 0.2) { $e.Lagrimas.RemoveAt($i) } }
    # las palabras de la canción que flotan (como en el vídeo)
    $cada = if (Wg-Llora) { 1800 } else { 5500 }
    if ($ahora - $e.LetraT -gt $cada -and $e.Letras.Count -lt 4 -and $k.Letras) { $e.LetraT = $ahora; Wg-Letra (Azar $k.Letras) }
    for ($i = $e.Letras.Count - 1; $i -ge 0; $i--) { $pal = $e.Letras[$i]; $pal.T++; $pal.Y -= 0.12; if ($pal.T -ge $pal.Vida) { $e.Letras.RemoveAt($i) } }
    # el rótulo de última hora avanza
    $e.TickerX += 1.6
    if ($e.TickerX -gt $e.TickerW + 360) { $e.TickerX = 0.0 }
    # respira (y si llora, solloza)
    $a = $script:actores['W']
    if ($a) {
        if (Wg-Llora) { $a.OX = [Math]::Sin($ahora / 90.0) * 1.2; $a.OY = 2 + [Math]::Abs([Math]::Sin($ahora / 260.0)) * 2.5 }
        else { $a.OX = [Math]::Sin($ahora / 1300.0) * 2; $a.OY = [Math]::Sin($ahora / 800.0) * 1.8 }
    }
    Invalidar-Escena
}
# ---- dibujo ----
function Wg-Oscurecer($c) { return (C ([int]($c.R * 0.36)) ([int]($c.G * 0.4)) ([int]($c.B * 0.56))) }
# una nube hecha de óvalos
function Wg-Nube($g, $x, $y, $s, $br) {
    $g.FillEllipse($br, [float]$x, [float]($y + 0.3 * $s), [float](1.2 * $s), [float](0.6 * $s))
    $g.FillEllipse($br, [float]($x + 0.35 * $s), [float]$y, [float](0.8 * $s), [float](0.8 * $s))
    $g.FillEllipse($br, [float]($x + 0.8 * $s), [float]($y + 0.2 * $s), [float](0.9 * $s), [float](0.65 * $s))
    $g.FillEllipse($br, [float]($x + 0.1 * $s), [float]($y + 0.45 * $s), [float](1.5 * $s), [float](0.42 * $s))
}
# el fondo guardado: la izquierda azul grisácea del vídeo y, a la derecha, el cielo según el tiempo
function Wg-Pintar-Fondo($g, $W, $H) {
    $cielo = Wg-Cielo; $noche = (Wg-Noche) -and $cielo -ne 'vivos'
    Degradado $g 0 0 $W $H (C 106 122 168) (C 76 90 138) 90
    $rn = New-Object System.Random 7
    $pl = New-Object System.Drawing.Pen((ARGB 46 255 255 255), 1)
    for ($i = 0; $i -lt 70; $i++) { $x = $rn.Next(0, 400); $y = $rn.Next(40, $H); $l = $rn.Next(6, 14); $g.DrawLine($pl, $x, $y, ($x - 1), ($y + $l)) }
    $pl.Dispose()
    # papel detrás de los botones
    $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
    $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 64 255 255 255))), $pan)
    $g.DrawPath((New-Object System.Drawing.Pen((ARGB 190 255 255 255), 1.2)), $pan); $pan.Dispose()
    # el cielo
    $c1, $c2 = switch ($cielo) {
        'sol' { (C 96 150 226), (C 186 212 244) }
        'lluvia' { (C 72 86 130), (C 118 132 172) }
        'tormenta' { (C 30 36 64), (C 72 82 120) }
        'nieve' { (C 150 164 196), (C 216 224 240) }
        'niebla' { (C 146 154 178), (C 200 204 218) }
        'vivos' { (C 54 120 236), (C 170 220 255) }
        default { (C 106 122 168), (C 160 172 204) }
    }
    if ($noche) { $c1 = Wg-Oscurecer $c1; $c2 = Wg-Oscurecer $c2 }
    $X0 = 404; $Y0 = 56; $SW = $W - 408; $SH = 222
    $g.SetClip((New-Object System.Drawing.Rectangle($X0, $Y0, $SW, $SH)))
    Degradado $g $X0 $Y0 $SW $SH $c1 $c2 90
    # arcoíris (cielos vivos)
    if ($cielo -eq 'vivos') {
        $arco = @((C 255 90 90), (C 255 170 70), (C 255 230 90), (C 110 220 120), (C 90 170 255), (C 150 110 240))
        for ($i = 0; $i -lt $arco.Count; $i++) { $r = 190 - $i * 9; $pa = New-Object System.Drawing.Pen((ARGB 150 $arco[$i].R $arco[$i].G $arco[$i].B), 9); $g.DrawArc($pa, [float](600 - $r), [float](300 - $r), [float](2 * $r), [float](2 * $r), 180, 180); $pa.Dispose() }
    }
    # sol o luna (arriba a la derecha, sobre su cabeza)
    if ($cielo -in @('sol', 'vivos', 'nubes')) {
        if ($noche) {
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 230 236 240 255))), 724, 64, 26, 26)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush($c1)), 732, 60, 26, 26)
        } elseif ($cielo -ne 'nubes') {
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse(700, 44, 76, 76)
            $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pgb.CenterColor = (ARGB 150 255 248 210); $pgb.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 255 248 210))
            $g.FillPath($pgb, $gp); $pgb.Dispose(); $gp.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 246 214))), 724, 68, 28, 28)
        }
    }
    # nubes
    $nn, $cn = switch ($cielo) {
        'sol' { 2, (ARGB 170 255 255 255) }
        'vivos' { 2, (ARGB 150 255 255 255) }
        'lluvia' { 7, (ARGB 225 140 150 182) }
        'tormenta' { 8, (ARGB 235 50 56 86) }
        'nieve' { 5, (ARGB 220 236 240 250) }
        'niebla' { 3, (ARGB 150 230 232 240) }
        default { 6, (ARGB 205 226 230 242) }
    }
    if ($noche) { $cn = [System.Drawing.Color]::FromArgb($cn.A, [int]($cn.R * 0.45), [int]($cn.G * 0.48), [int]($cn.B * 0.6)) }
    $bn = New-Object System.Drawing.SolidBrush($cn); $rn = New-Object System.Random 3
    for ($i = 0; $i -lt $nn; $i++) { Wg-Nube $g ($X0 - 30 + $rn.Next(0, $SW)) (44 + $rn.Next(0, 70)) (46 + $rn.Next(0, 40)) $bn }
    $bn.Dispose()
    # edificios (como los del vídeo), con ventanas encendidas de noche o con tormenta
    $rn = New-Object System.Random 21
    $bc = if ($noche) { (C 14 18 34) } else { (C 34 40 70) }
    $bb = New-Object System.Drawing.SolidBrush($bc)
    $luz = New-Object System.Drawing.SolidBrush((ARGB 200 255 226 150))
    $x = $X0 - 6
    while ($x -lt $W) {
        $bw = $rn.Next(26, 54); $bh = $rn.Next(28, 96); $top = 262 - $bh
        $g.FillRectangle($bb, $x, $top, $bw, ($bh + 20))
        if ($noche -or $cielo -eq 'tormenta') {
            for ($wy = $top + 6; $wy -lt 256; $wy += 9) { for ($wx = $x + 4; $wx -lt $x + $bw - 5; $wx += 8) { if ($rn.Next(4) -eq 0) { $g.FillRectangle($luz, $wx, $wy, 3, 4) } } }
        }
        $x += $bw + $rn.Next(0, 6)
    }
    $bb.Dispose(); $luz.Dispose()
    # niebla: bandas blancas
    if ($cielo -eq 'niebla') { for ($i = 0; $i -lt 4; $i++) { Degradado $g $X0 (120 + $i * 36) $SW 30 (ARGB 0 236 238 244) (ARGB 120 236 238 244) 90 } }
    $g.ResetClip()
    # marco de la "tele"
    $g.DrawRectangle((New-Object System.Drawing.Pen((ARGB 200 255 255 255), 1.4)), $X0, $Y0, $SW, $SH)
}
# icono del tiempo (dibujo de líneas gruesas, como los del vídeo)
function Wg-Icono($g, $cielo, $noche, $x, $y, $s, $col) {
    $br = New-Object System.Drawing.SolidBrush($col); $pen = New-Object System.Drawing.Pen($col, [float]([Math]::Max(1.5, $s / 14.0))); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $nube = { param($dy) Wg-Nube $g ($x + 0.05 * $s) ($y + $dy) (0.62 * $s) $br }
    switch ($cielo) {
        { $_ -in @('sol', 'vivos') } {
            if ($noche -and $cielo -eq 'sol') {
                $g.FillEllipse($br, [float]($x + 0.2 * $s), [float]($y + 0.15 * $s), [float](0.6 * $s), [float](0.6 * $s))
                $g.FillEllipse([System.Drawing.Brushes]::White, [float]($x + 0.38 * $s), [float]($y + 0.06 * $s), [float](0.6 * $s), [float](0.6 * $s))
            } else {
                $cx = $x + 0.5 * $s; $cy = $y + 0.45 * $s
                $g.FillEllipse($br, [float]($cx - 0.2 * $s), [float]($cy - 0.2 * $s), [float](0.4 * $s), [float](0.4 * $s))
                for ($i = 0; $i -lt 8; $i++) { $an = $i * [Math]::PI / 4; $g.DrawLine($pen, [float]($cx + [Math]::Cos($an) * 0.28 * $s), [float]($cy + [Math]::Sin($an) * 0.28 * $s), [float]($cx + [Math]::Cos($an) * 0.42 * $s), [float]($cy + [Math]::Sin($an) * 0.42 * $s)) }
            }
        }
        'nubes' { & $nube (0.15 * $s) }
        'lluvia' { & $nube 0; for ($i = 0; $i -lt 3; $i++) { $lx = $x + (0.3 + 0.2 * $i) * $s; $g.DrawLine($pen, [float]$lx, [float]($y + 0.62 * $s), [float]($lx - 0.08 * $s), [float]($y + 0.88 * $s)) } }
        'tormenta' {
            & $nube 0
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 0.52 * $s), [float]($y + 0.55 * $s))), (New-Object System.Drawing.PointF([float]($x + 0.38 * $s), [float]($y + 0.78 * $s))), (New-Object System.Drawing.PointF([float]($x + 0.5 * $s), [float]($y + 0.78 * $s))), (New-Object System.Drawing.PointF([float]($x + 0.42 * $s), [float]($y + 0.98 * $s))), (New-Object System.Drawing.PointF([float]($x + 0.64 * $s), [float]($y + 0.7 * $s))), (New-Object System.Drawing.PointF([float]($x + 0.52 * $s), [float]($y + 0.7 * $s))))
            $g.FillPolygon($br, $pts)
        }
        'nieve' { & $nube 0; for ($i = 0; $i -lt 3; $i++) { $g.FillEllipse($br, [float]($x + (0.28 + 0.2 * $i) * $s), [float]($y + (0.68 + 0.1 * ($i % 2)) * $s), [float](0.09 * $s), [float](0.09 * $s)) } }
        'niebla' { for ($i = 0; $i -lt 3; $i++) { $g.DrawLine($pen, [float]($x + (0.12 + 0.06 * ($i % 2)) * $s), [float]($y + (0.3 + 0.2 * $i) * $s), [float]($x + (0.88 - 0.06 * ($i % 2)) * $s), [float]($y + (0.3 + 0.2 * $i) * $s)) } }
    }
    $br.Dispose(); $pen.Dispose()
}
# un paraguas azul oscuro (el de la portada de la canción) sobre su cabeza
function Wg-Dibujar-Paraguas($g, $cx, $cy, $ancho) {
    $r = $ancho / 2.0; $alto = $r * 0.5; $n = 6
    $pts = New-Object System.Collections.ArrayList
    for ($i = 0; $i -le 24; $i++) { $an = [Math]::PI + $i * [Math]::PI / 24; [void]$pts.Add((New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($an) * $r), [float]($cy + $alto + [Math]::Sin($an) * $alto)))) }
    for ($i = $n; $i -ge 0; $i--) {
        $bx = $cx - $r + 2 * $r * $i / $n
        [void]$pts.Add((New-Object System.Drawing.PointF([float]$bx, [float]($cy + $alto))))
        if ($i -gt 0) { [void]$pts.Add((New-Object System.Drawing.PointF([float]($bx - $r / $n), [float]($cy + $alto * 0.82)))) }
    }
    $arr = [System.Drawing.PointF[]]$pts.ToArray()
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 70 0 0 20))), [System.Drawing.PointF[]]($arr | ForEach-Object { New-Object System.Drawing.PointF([float]($_.X + 3), [float]($_.Y + 4)) }))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 38 50 96))), $arr)
    $vp = New-Object System.Drawing.Pen((ARGB 150 150 170 230), 1.2)
    for ($i = 0; $i -le $n; $i++) { $g.DrawLine($vp, [float]$cx, [float]$cy, [float]($cx - $r + 2 * $r * $i / $n), [float]($cy + $alto)) }
    $vp.Dispose()
    $g.DrawPolygon((New-Object System.Drawing.Pen((C 20 26 56), 1.4)), $arr)
    $g.DrawLine((New-Object System.Drawing.Pen((C 20 26 56), 2)), [float]$cx, [float]($cy - 7), [float]$cx, [float]$cy)
}
# todo lo que se mueve, por encima de Eleanor
function Wg-Pintar($g, $W, $H, $k) {
    Wg-Reset; $e = $script:wg; $ahora = [Environment]::TickCount
    $cielo = Wg-Cielo; $noche = (Wg-Noche) -and $cielo -ne 'vivos'; $llora = Wg-Llora
    $a = $script:actores['W']; $ax = 540.0; $ay = 98.0; $aw = 220.0; $ah = 220.0
    if ($a) { $ax = $a.Rect[0] + $a.OX; $ay = $a.Rect[1] + $a.OY; $aw = $a.Rect[2]; $ah = $a.Rect[3] }
    $bajo = $ahora -lt $e.Paraguas
    $g.SetClip((New-Object System.Drawing.Rectangle(404, 56, ($W - 408), 222)))
    # el paraguas sobre su cabeza
    if ($bajo) { Wg-Dibujar-Paraguas $g ($ax + $aw * 0.5) ($ay - 30) ($aw * 0.86) }
    # lágrimas
    if ($llora -and $e.Lagrimas.Count -gt 0) {
        $bl = New-Object System.Drawing.SolidBrush((ARGB 225 120 175 255))
        foreach ($l in $e.Lagrimas) { $tx = $ax + $l.FX * $aw; $ty = $ay + ($l.FY + $l.D) * $ah; $g.FillEllipse($bl, [float]($tx - 2), [float]($ty - 3), 4.0, 6.5) }
        $bl.Dispose()
    }
    # lluvia o nieve, por delante (como en el vídeo); bajo el paraguas no llueve
    if ($e.Gotas.Count -gt 0) {
        if ($cielo -eq 'nieve') {
            $bn = New-Object System.Drawing.SolidBrush((ARGB 225 255 255 255))
            foreach ($d in $e.Gotas) { $s = 2 + ($d.L % 3); $g.FillEllipse($bn, [float]$d.X, [float]$d.Y, [float]$s, [float]$s) }
            $bn.Dispose()
        } else {
            $pl = New-Object System.Drawing.Pen((ARGB $(if ($cielo -eq 'tormenta') { 170 } else { 125 }) 235 240 255), 1.1)
            $vx = if ($cielo -eq 'tormenta') { -4.0 } else { -1.8 }
            $pa1 = $ax + $aw * 0.07; $pa2 = $ax + $aw * 0.93; $pay = $ay - 8
            foreach ($d in $e.Gotas) {
                if ($bajo -and $d.X -gt $pa1 -and $d.X -lt $pa2 -and $d.Y -gt $pay) { continue }
                $g.DrawLine($pl, [float]$d.X, [float]$d.Y, [float]($d.X + $vx * $d.L / 8.0), [float]($d.Y + $d.L))
            }
            $pl.Dispose()
        }
    }
    # el rayo: un fogonazo suave y la línea quebrada (nada de esto en el modo seguro)
    if ($e.Rayo -gt 0) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](24 * $e.Rayo)) 230 235 255))), 404, 56, ($W - 408), 222)
        if ($e.Rayo -gt 3) {
            $rr = New-Object System.Random ($e.RayoX); $px = $e.RayoX; $py = 56
            $pr = New-Object System.Drawing.Pen((ARGB 230 250 250 255), 2)
            while ($py -lt 190) { $nx = $px + $rr.Next(-14, 15); $ny = $py + $rr.Next(14, 26); $g.DrawLine($pr, [float]$px, [float]$py, [float]$nx, [float]$ny); $px = $nx; $py = $ny }
            $pr.Dispose()
        }
    }
    # al abrirse el cielo, un brillo que se apaga despacio
    if ($e.Fx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](6 * $e.Fx)) 255 250 220))), 404, 56, ($W - 408), 222) }
    # las palabras de la canción
    foreach ($pal in $e.Letras) {
        $q = $pal.T / [double]$pal.Vida
        $al = [int](215 * [Math]::Max(0.0, [Math]::Min(1.0, [Math]::Min($q * 4.0, (1.0 - $q) * 3.0))))
        if ($al -le 0) { continue }
        $f = FntP('Georgia', $pal.Tam, [System.Drawing.FontStyle]::Italic)
        $g.DrawString($pal.Txt, $f, (New-Object System.Drawing.SolidBrush((ARGB ([int]($al * 0.35)) 20 26 56))), [float]($pal.X + 1), [float]($pal.Y + 1))
        $g.DrawString($pal.Txt, $f, (New-Object System.Drawing.SolidBrush((ARGB $al 255 255 255))), [float]$pal.X, [float]$pal.Y)
        $f.Dispose()
    }
    $g.ResetClip()
    # la tarjeta del tiempo
    $t = $WgTarjeta; $tx = $t[0]; $ty = $t[1]; $tw = $t[2]; $th = $t[3]
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 10 14 40))), ($tx + 3), ($ty + 3), $tw, $th)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 238 248 249 253))), $tx, $ty, $tw, $th)
    $cab, $txtCab = if ($llora) { (C 196 40 52), 'AVISO ROJO' } elseif ($cielo -eq 'vivos') { (C 63 91 217), 'CIELOS VIVOS' } else { (C 38 48 92), 'EL TIEMPO' }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($cab)), $tx, $ty, $tw, 17)
    $fc = FntP('Georgia', 7.5, [System.Drawing.FontStyle]::Bold)
    $g.DrawString($txtCab, $fc, [System.Drawing.Brushes]::White, [float]($tx + 5), [float]($ty + 2))
    # el "◉ REC" del vídeo (en el modo seguro no parpadea)
    $on = $script:aj.Epilepsia -or ([int]($ahora / 700) % 2 -eq 0)
    if ($on) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 70 70))), [float]($tx + $tw - 36), [float]($ty + 5), 7.0, 7.0) }
    $g.DrawString('REC', (FntP('Consolas', 6.5, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, [float]($tx + $tw - 27), [float]($ty + 3))
    $tinta = (C 30 38 74)
    if ($llora) {
        # durante la tormenta, la tarjeta enseña la portada de la canción
        if (-not $script:wgPortada) { $script:wgPortada = Cargar-Img $k.Portada }
        if ($script:wgPortada) { Imagen-Cubrir $g $script:wgPortada ($tx + 4) ($ty + 21) ($tw - 8) ($th - 54) 0.5 0.4 }
        $g.DrawString('TORMENTA EN EL PLATÓ', (FntP('Georgia', 7, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 196 40 52))), [float]($tx + 5), [float]($ty + $th - 31))
    } else {
        Wg-Icono $g $cielo $noche ($tx + 6) ($ty + 22) 44 (C 38 48 92)
        $g.DrawString("$($e.Temp)°", (FntP('Georgia', 22, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($tinta)), [float]($tx + 52), [float]($ty + 22))
        $desc = if ($cielo -eq 'vivos') { 'Cielos vivos' } else { $e.Desc }
        $fd = FntP('Georgia', 7.5, [System.Drawing.FontStyle]::Italic)
        $g.DrawString($desc, $fd, (New-Object System.Drawing.SolidBrush($tinta)), (New-Object System.Drawing.RectangleF([float]($tx + 5), [float]($ty + 66), [float]($tw - 10), 24.0)))
        $lug = if ($e.Lugar) { $e.Lugar } elseif ($e.Pedido) { 'conectando...' } else { 'sin conexión: a ojo' }
        $g.DrawString($lug, (FntP('Segoe UI', 6.5)), (New-Object System.Drawing.SolidBrush((C 110 118 150))), (New-Object System.Drawing.RectangleF([float]($tx + 5), [float]($ty + 89), [float]($tw - 10), 12.0)))
        Wg-Icono $g $e.MCielo $false ($tx + 5) ($ty + 101) 16 (C 63 91 217)
        $g.DrawString(("mañana  {0}° / {1}°" -f $e.Min, $e.Max), (FntP('Georgia', 7)), (New-Object System.Drawing.SolidBrush($tinta)), [float]($tx + 24), [float]($ty + 103))
    }
    # palabras sin decir: seis gotitas que se van llenando
    $g.DrawString('sin decir:', (FntP('Georgia', 6.5, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((C 110 118 150))), [float]($tx + 5), [float]($ty + $th - 15))
    for ($i = 0; $i -lt $WgTiempos.PalabrasMax; $i++) {
        $gx = $tx + 50 + $i * 7.5; $gy = $ty + $th - 12
        $col = if ($i -lt $e.Palabras) { if ($llora) { (C 196 40 52) } else { (C 63 91 217) } } else { (C 210 214 228) }
        $g.FillEllipse((New-Object System.Drawing.SolidBrush($col)), [float]$gx, [float]$gy, 5.5, 7.0)
    }
    # el paraguas para dárselo
    if (Wg-Paraguas-Visible) {
        $r = $WgParaguasBtn
        $hover = Wg-Paraguas-En-Raton
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 10 14 40))), ($r[0] + 2), ($r[1] + 2), $r[2], $r[3])
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 63 91 217) } else { (ARGB 238 248 249 253) }))), $r[0], $r[1], $r[2], $r[3])
        $tc = if ($hover) { [System.Drawing.Color]::White } else { $tinta }
        $g.DrawString('☂', (FntP('Segoe UI Symbol', 12)), (New-Object System.Drawing.SolidBrush($tc)), [float]($r[0] + 3), [float]($r[1] + 2))
        $g.DrawString('dale el paraguas', (FntP('Georgia', 8, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush($tc)), [float]($r[0] + 24), [float]($r[1] + 6))
    }
    # el rótulo de última hora
    $by = 262; $bx = 404; $bw = $W - 408
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 238 22 28 56))), $bx, $by, $bw, 15)
    $lab = if ($llora) { 'AVISO' } else { 'ÚLTIMA HORA' }
    $fl = FntP('Segoe UI', 7, [System.Drawing.FontStyle]::Bold); $lw = $g.MeasureString($lab, $fl).Width + 8
    $g.SetClip((New-Object System.Drawing.Rectangle([int]($bx + $lw), $by, [int]($bw - $lw), 15)))
    $ft = FntP('Segoe UI', 7); $e.TickerW = [double]$g.MeasureString($e.Ticker, $ft).Width
    $g.DrawString($e.Ticker, $ft, [System.Drawing.Brushes]::White, [float]($bx + $bw - $e.TickerX), [float]($by + 1))
    $g.ResetClip()
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($llora) { (C 196 40 52) } else { (C 63 91 217) }))), $bx, $by, [float]$lw, 15)
    $g.DrawString($lab, $fl, [System.Drawing.Brushes]::White, [float]($bx + 4), [float]($by + 1))
}
# --- Weathergirl: la intro del videoclip (FLAVOR FOLEY presents... sobre el cielo nublado, y luego el titular del parte
#     y la tele con "weathergirl", feat. Eleanor Forte, MV by ippo.tsk). Va como la de Tetra: el reloj es el audio. ---
function Transicion-Clima($final) {
    $script:wiIntro = Cargar-Img $script:skin.IntroImg
    $script:wiInfo = if ($script:wiIntro) { Gif-Info $script:wiIntro } else { @{ N = 1; Del = @(100) } }
    $script:wiMs = 0; foreach ($d in $script:wiInfo.Del) { $script:wiMs += $d }
    $script:wiT0 = 0; $script:wiSaltar = $false; $script:wgIntroAudio = $null; $script:wiFin = -1
    $script:iRecursos = @($script:wiIntro)
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $img = $script:wiIntro; if (-not $img) { return }
        $ms = Wg-Intro-Ms
        Gif-Frame $img $script:wiInfo ([int][Math]::Max(0.0, [Math]::Min([double]$ms, [double]($script:wiMs - 1))))
        $g.InterpolationMode = 'HighQualityBilinear'
        # detrás, el mismo fotograma ampliado y teñido del azul grisáceo del vídeo rellena los lados
        $sc = [Math]::Max([double]($W / $img.Width), [double]($H / $img.Height)); $cw = $img.Width * $sc; $ch = $img.Height * $sc
        $g.DrawImage($img, [float](($W - $cw) / 2), [float](($H - $ch) / 2), [float]$cw, [float]$ch)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 40 48 86))), 0, 0, $W, $H)
        $s = [Math]::Min([double]($W / $img.Width), [double]($H / $img.Height)); $vw = $img.Width * $s; $vh = $img.Height * $s
        $g.DrawImage($img, [float](($W - $vw) / 2), [float](($H - $vh) / 2), [float]$vw, [float]$vh)
        $a = 0.0
        if ($ms -lt 300) { $a = 1 - $ms / 300.0 }
        $resta = $script:wiMs - $ms; if ($resta -lt 400) { $a = 1 - $resta / 400.0 }
        $a = [Math]::Max(0.0, [Math]::Min(1.0, $a))
        if ($a -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $a)) 0 0 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        if ($script:wiSaltar -or (Wg-Intro-Ms) -ge $script:wiMs) {
            Wg-Intro-Terminar
            if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        }
    }
    # el vídeo y su audio arrancan a la vez
    $script:wiT0 = [Environment]::TickCount
    if ($script:aj.Sonido) {
        try {
            $mp = New-Object System.Windows.Media.MediaPlayer
            $mp.Open([Uri](Ruta $script:skin.IntroAudio)); $mp.Volume = (Wg-Volumen); $mp.Play()
            $script:wgIntroAudio = $mp
        } catch { $script:wgIntroAudio = $null }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    $script:iOv.Add_MouseDown({ $script:wiSaltar = $true })
    $script:iOv.Cursor = 'Hand'
}
# milisegundos de intro: manda el audio; si no hay sonido (o aún no ha arrancado), el reloj del sistema
function Wg-Intro-Ms {
    if ($script:wiT0 -le 0) { return 0 }
    $ms = [Environment]::TickCount - $script:wiT0
    if ($script:wgIntroAudio) {
        try { $pa = $script:wgIntroAudio.Position.TotalMilliseconds; if ($pa -gt 0) { $ms = $pa } } catch {}
    }
    return [double]$ms
}
# fin de la intro (o SALTAR): se calla el audio del vídeo y la instrumental sigue por el mismo punto de la canción
function Wg-Intro-Terminar {
    if ($script:wiFin -ge 0 -or $script:wiT0 -le 0) { return }
    $ms = [Math]::Min([double](Wg-Intro-Ms), [double]$script:wiMs); $script:wiFin = $ms
    if ($script:wgIntroAudio) { try { $script:wgIntroAudio.Stop(); $script:wgIntroAudio.Close() } catch {}; $script:wgIntroAudio = $null }
    $mv = if ($ms -lt $WgIntro.CorteMs) { $ms } else { $WgIntro.SegundoDesde + ($ms - $WgIntro.CorteMs) }
    Wg-Musica-Off; Wg-Musica-On ([Math]::Max(0.0, [double]($mv - $WgIntro.Desfase)))
}

# ================= PAINTER (Pressure): LA IA QUE SOLO QUIERE PINTAR PAISAJES =================
# Painter (Z-779) es el ordenador de los 80 del Hadal Blacksite. Su pantalla es un programa de dibujo: GARABATEA CARAS
# para expresarse (se dibujan por código, trazo a trazo, sobre su pantalla en blanco) y quiere PINTAR UN PAISAJE.
# Cada app que abres es un elemento del paisaje (cielo, sol, colinas, árbol, río, casita): a la 6ª lo termina y se
# alegra. Pero Urbanshade lo tiene MINANDO CRIPTOMONEDA: cada app también le sube el OVERCLOCK (calor). Si llega a
# 100, se pone a MINAR a la fuerza: la pantalla se llena de hashes, pide perdón ("por favor, para...") y PIERDE el
# paisaje. Un clic en él lo refresca (-25°) y le saca una sonrisa; con un poco de tiempo se enfría solo.
$PrTiempos = @{ CalorApp = 22.0; CalorSola = 0.02; Enfriar = 25.0; EnfriarEspera = 1800; Paisaje = 6; MinaMs = 7500; ListoMs = 22000; Dibuja = 800; Inicial = 10.0; DibujoMs = 2600 }
# el lienzo dentro de la ventana de su programa (en proporción): x0, x1, y0, y1
$PrCanvas = @(0.0912, 0.7059, 0.1613, 0.8065)
# el panel de datos (a la derecha, dentro de la ventana)
$PrPanel = @(0.7324, 0.9912, 0.1452, 0.8495)
$PrElementos = @('PaisajeCielo', 'PaisajeSol', 'PaisajeColinas', 'PaisajeArbol', 'PaisajeRio', 'PaisajeCasa')
# la intro: arranque del ordenador y su programa de dibujo (milisegundos desde que empieza)
$PrIntro = @{ Abre = 5300; Cara = 5900; Mueve = 7500; Titulo = 8100; Sub = 8700; Frase = 9400; Guino = 11000; Fin = 13600 }
$script:pr = $null; $script:prMusica = $null; $script:prCaras = @{}
function Pr-Reset {
    if (-not $script:pr) {
        $script:pr = @{ Calor = $PrTiempos.Inicial; Paisaje = 0; Terminados = 0; Cara = 'feliz'; CaraT = 0; CaraHasta = 0; ElemT = 0
            Mina = 0; MinaIni = 0; MinaDicho = $false; Enfria = 0; Listo = 0; Ciclo = 0; Saludado = $false; Humor = 'feliz'; HumorHasta = 0; Ult = [Environment]::TickCount; Dib = (New-Object System.Collections.ArrayList); DibProx = 0; Borra = 0; Hex = (New-Object System.Collections.ArrayList) }
    }
}
function Pr-Mina-Activa { return ($script:pr -and [Environment]::TickCount -lt $script:pr.Mina) }
function Pr-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.75 * $script:aj.Volumen / 100.0)) }
function Pr-Musica-On {
    if (-not $script:aj.Sonido -or $script:prMusica) { return }
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta 'skins\painter\cancion.mp3')); $mp.Volume = (Pr-Volumen); $mp.Play()
        $script:prMusica = $mp
    } catch { $script:prMusica = $null }
}
function Pr-Musica-Off {
    if ($script:prMusica) { try { $script:prMusica.Stop(); $script:prMusica.Close() } catch {}; $script:prMusica = $null }
}
# su cara: la dibuja trazo a trazo durante un rato
function Pr-Cara($nombre, $ms, $silencio) {
    $e = $script:pr; $ahora = [Environment]::TickCount
    $e.Cara = $nombre; $e.CaraT = $ahora; $e.CaraHasta = $ahora + $ms
    if (-not $silencio) { Sonido 'blip' }; $form.Invalidate()
}
# cada app: un elemento más del paisaje... y más calor
function Pr-App($linea, $nombre) {
    Pr-Reset; $e = $script:pr; $k = $script:skin; $ahora = [Environment]::TickCount
    Sonido 'blip'; $e.Ult = $ahora
    if (Pr-Mina-Activa) { Decir (Azar $k.Perdon); return }
    $antes = $e.Calor
    $e.Calor = [Math]::Min(100.0, $e.Calor + $PrTiempos.CalorApp)
    # si ya había uno terminado, empieza otro lienzo
    if ($e.Listo -gt $ahora) { $e.Listo = 0; $e.Paisaje = 0 }
    $e.Paisaje++; $e.ElemT = $ahora; $e.Dib.Clear(); $e.Borra = 0
    # terminarlo va antes que sobrecalentarse
    if ($e.Paisaje -ge $PrTiempos.Paisaje) { Pr-Listo; return }
    if ($e.Calor -ge 100.0) { Pr-Mina; return }
    Sonido 'garabato'
    if ($antes -lt 70.0 -and $e.Calor -ge 70.0) { Sonido 'ventilador'; Pr-Cara 'susto' 3500; if (-not (Pr-Voz 'calor')) { Decir (Azar $k.Calentando) }; return }
    if ($e.Calor -ge 70.0 -and $Rnd.Next(100) -lt 55) { Decir (Azar $k.Calentando); return }
    if ($Rnd.Next(100) -lt 30 -and (Pr-Voz 'app')) { return }
    if ($Rnd.Next(100) -lt 55) { Decir (Azar $k[$PrElementos[$e.Paisaje - 1]]); return }
    Decir $linea
}
# el overclock llega al límite: a minar por la fuerza
function Pr-Mina {
    $e = $script:pr; $k = $script:skin; $ahora = [Environment]::TickCount
    $e.Mina = $ahora + $PrTiempos.MinaMs; $e.MinaIni = $ahora; $e.MinaDicho = $false
    $e.Paisaje = 0; $e.Calor = 100.0; $e.Hex.Clear(); $e.Dib.Clear(); $e.Borra = 0
    Sonido 'error'; Sonido 'ventilador'
    Pr-Voz-Off; if (-not (Pr-Voz 'mina' $true)) { Decir-Fijo (Azar $k.Minando) }
    $form.Invalidate()
}
# el paisaje, terminado
function Pr-Listo {
    $e = $script:pr; $k = $script:skin; $ahora = [Environment]::TickCount
    $e.Listo = $ahora + $PrTiempos.ListoMs; $e.Terminados++; $e.Calor = 30.0
    Sonido 'listo'
    Flotante '★' 640 120 (C 255 214 90) 22 'Segoe UI Symbol'; Flotante '♥' 700 150 (C 255 130 190) 18 'Segoe UI Symbol'
    if ($Rnd.Next(2) -eq 0 -or -not (Pr-Voz 'listo' $true)) { Decir-Fijo (Azar $k.PaisajeListo) }
}
function Pr-Clic {
    Pr-Reset; $e = $script:pr; $k = $script:skin; $ahora = [Environment]::TickCount
    if (Pr-Mina-Activa) { Decir (Azar $k.Perdon); return }
    $dormia = ($ahora - $e.Ult) -gt 75000; $e.Ult = $ahora
    if ($dormia) { Pr-Cara 'sorpresa' 2200; Decir (Azar $k.Clic); return }
    if ($ahora - $e.Enfria -lt $PrTiempos.EnfriarEspera) { Pr-Cara (Azar @('risa', 'curioso', 'sorpresa', 'enamorado')) 1800 $true; Decir (Azar $k.Clic); return }
    $e.Enfria = $ahora
    if ($e.Calor -ge 70.0) { Flotante '-25°' 560 70 (C 120 210 230) 15 'Consolas'; $e.Calor = [Math]::Max(0.0, $e.Calor - $PrTiempos.Enfriar); Sonido 'ventilador'; Pr-Cara 'neutra' 3000; if (-not (Pr-Voz 'enfriar')) { Decir (Azar $k.Caliente) }; return }
    if ($e.Calor -ge 35.0) { Flotante '-25°' 560 70 (C 120 210 230) 15 'Consolas'; $e.Calor = [Math]::Max(0.0, $e.Calor - $PrTiempos.Enfriar); Pr-Cara 'feliz' 3000; if ($Rnd.Next(2) -eq 0 -or -not (Pr-Voz 'enfriar')) { Decir (Azar $k.Enfriar) }; return }
    Pr-Cara (Azar @('risa', 'guino', 'contento', 'enamorado', 'curioso', 'sorpresa')) 2600; if ($Rnd.Next(100) -ge 45 -or -not (Pr-Voz 'clic')) { Decir (Azar $k.Clic) }
}
function Pr-Tick {
    Pr-Reset; $e = $script:pr; $k = $script:skin; $ahora = [Environment]::TickCount
    # la música del altavoz: se repite al acabar, sigue el volumen y se calla sin sonido
    if (-not $script:aj.Sonido) { Pr-Musica-Off }
    elseif (-not $script:prMusica) { Pr-Musica-On }
    else {
        try {
            $mp = $script:prMusica
            $vt = (Pr-Volumen) * $(if (Pr-Voz-Suena) { 0.3 } else { 1.0 }); if ([Math]::Abs($mp.Volume - $vt) -gt 0.01) { $mp.Volume = $vt }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    $e.Ciclo++
    if (-not $e.Saludado -and -not (Ocupado)) { $e.Saludado = $true; [void](Pr-Voz 'hola') }
    if ($ahora -lt $e.Mina) {
        # minando: los hashes suben por la pantalla; a mitad pide perdón; el calor baja despacio
        if (($e.Ciclo % 2) -eq 0) {
            $linea = ''; for ($i = 0; $i -lt 14; $i++) { $linea += '0123456789abcdef'[$Rnd.Next(16)] }
            [void]$e.Hex.Add($linea); while ($e.Hex.Count -gt 9) { $e.Hex.RemoveAt(0) }
        }
        $q = ($ahora - $e.MinaIni) / [double]$PrTiempos.MinaMs
        $e.Calor = [Math]::Max(60.0, 100.0 - 40.0 * $q)
        if (-not $e.MinaDicho -and $q -ge 0.5) { $e.MinaDicho = $true; Sonido 'minando'; if (-not (Pr-Voz-Suena)) { if (-not (Pr-Voz 'perdon' $true)) { Decir-Fijo (Azar $k.Perdon) } } }
    } elseif ($e.Mina -ne 0) {
        # se acabó: vuelve en sí, triste
        $e.Mina = 0; $e.Calor = 40.0; $e.Hex.Clear()
        Pr-Cara 'triste' 6000; if (-not (Pr-Voz 'minafin' $true)) { Decir-Fijo (Azar $k.MinaFin) }
    } else {
        $e.Calor = [Math]::Max(0.0, $e.Calor - $PrTiempos.CalorSola)
    }
    # su humor cambia solo de vez en cuando; al acabar un dibujo, se alegra
    if ($ahora -ge $e.HumorHasta) { $e.Humor = Azar $PrHumores; $e.HumorHasta = $ahora + 5000 + $Rnd.Next(0, 6000) }
    if ($e.Dib.Count -gt 0) { $ud = $e.Dib[$e.Dib.Count - 1]; if (-not $ud.Fin -and $ahora - $ud.T0 -ge $PrTiempos.DibujoMs) { $ud.Fin = $true; Pr-Cara (Azar @('contento', 'orgulloso', 'risa', 'enamorado', 'feliz')) 1700 $true } }
    # cuando no pinta el paisaje, dibuja cosas sueltas; con el lienzo lleno, lo borra con la goma y vuelve a empezar
    if ($ahora -ge $e.Mina -and $e.Paisaje -le 0) {
        if ($e.Borra -ne 0) { if ($ahora - $e.Borra -ge 900) { $e.Dib.Clear(); $e.Borra = 0; $e.DibProx = $ahora + 1200 } }
        elseif ($ahora -ge $e.DibProx -and -not (Ocupado) -and ($ahora - $e.Ult) -lt 75000) { if ($e.Dib.Count -ge 6) { $e.Borra = $ahora; Sonido 'garabato' } else { Pr-Nuevo-Dibujo } }
    }
    # el paisaje terminado se queda un rato y luego empieza otro lienzo
    if ($e.Listo -ne 0 -and $ahora -ge $e.Listo) { $e.Listo = 0; $e.Paisaje = 0; $e.DibProx = $ahora + 1500; Pr-Cara 'feliz' 4000 }
    # la pantalla del ordenador: se mueve un poco; con calor tiembla (no en el modo seguro)
    $a = $script:actores['P']
    if ($a) {
        $tem = 0.0
        if ($ahora -lt $e.Mina) { $tem = 2.0 } elseif ($e.Calor -ge 60.0) { $tem = ($e.Calor - 60.0) / 40.0 * 1.4 }
        if ($script:aj.Epilepsia) { $tem = 0.0 }
        $a.OX = [Math]::Sin($ahora / 1700.0) * 1.2 + ($Rnd.NextDouble() - 0.5) * $tem
        $a.OY = [Math]::Sin($ahora / 1100.0) * 1.0 + ($Rnd.NextDouble() - 0.5) * $tem
    }
    Invalidar-Escena
}
# ---- su pantalla: caras garabateadas ----
# un círculo hecho de vueltas descuidadas (como los ojos del dibujo del juego)
function Pr-Garabato($cx, $cy, $rx, $ry, $sem) {
    $rn = New-Object System.Random $sem; $lista = New-Object System.Collections.ArrayList
    $n = 46
    for ($i = 0; $i -le $n; $i++) {
        $q = $i / [double]$n; $an = $q * 2.5 * 2 * [Math]::PI + 0.6
        $f = 1.0 + 0.07 * [Math]::Sin($q * 9.0) - 0.15 * $q + ($rn.NextDouble() - 0.5) * 0.07
        [void]$lista.Add((New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($an) * $rx * $f), [float]($cy + [Math]::Sin($an) * $ry * $f))))
    }
    return , $lista.ToArray()
}
# una curva suave (de un punto a otro, con uno de control), con un poco de temblor
function Pr-Curva($x0, $y0, $x1, $y1, $x2, $y2, $sem) {
    $rn = New-Object System.Random $sem; $lista = New-Object System.Collections.ArrayList
    $n = 22
    for ($i = 0; $i -le $n; $i++) {
        $q = $i / [double]$n; $m = 1.0 - $q
        $px = $m * $m * $x0 + 2 * $m * $q * $x1 + $q * $q * $x2 + ($rn.NextDouble() - 0.5) * 0.012
        $py = $m * $m * $y0 + 2 * $m * $q * $y1 + $q * $q * $y2 + ($rn.NextDouble() - 0.5) * 0.012
        [void]$lista.Add((New-Object System.Drawing.PointF([float]$px, [float]$py)))
    }
    return , $lista.ToArray()
}
function Pr-Recta($pts) {
    $lista = New-Object System.Collections.ArrayList
    foreach ($q in $pts) { [void]$lista.Add((New-Object System.Drawing.PointF([float]$q[0], [float]$q[1]))) }
    return , $lista.ToArray()
}
function Pr-Trazos($nombre) {
    if ($script:prCaras.ContainsKey($nombre)) { return $script:prCaras[$nombre] }
    $t = New-Object System.Collections.ArrayList
    switch ($nombre) {
        'feliz' { [void]$t.Add((Pr-Garabato 0.30 0.38 0.13 0.16 1)); [void]$t.Add((Pr-Garabato 0.70 0.38 0.13 0.16 2)); [void]$t.Add((Pr-Curva 0.16 0.64 0.50 1.0 0.84 0.64 3)) }
        'triste' {
            [void]$t.Add((Pr-Garabato 0.30 0.44 0.10 0.13 4)); [void]$t.Add((Pr-Garabato 0.70 0.44 0.10 0.13 5))
            [void]$t.Add((Pr-Recta @(@(0.14, 0.26), @(0.42, 0.14)))); [void]$t.Add((Pr-Recta @(@(0.58, 0.14), @(0.86, 0.26))))
            [void]$t.Add((Pr-Curva 0.26 0.84 0.50 0.58 0.74 0.84 6))
        }
        'llora' {
            [void]$t.Add((Pr-Garabato 0.30 0.40 0.10 0.13 7)); [void]$t.Add((Pr-Garabato 0.70 0.40 0.10 0.13 8))
            [void]$t.Add((Pr-Curva 0.26 0.84 0.50 0.60 0.74 0.84 9))
            [void]$t.Add((Pr-Recta @(@(0.27, 0.56), @(0.25, 0.70), @(0.27, 0.84)))); [void]$t.Add((Pr-Recta @(@(0.73, 0.56), @(0.75, 0.70), @(0.73, 0.84))))
        }
        'enfado' {
            [void]$t.Add((Pr-Garabato 0.30 0.44 0.07 0.09 10)); [void]$t.Add((Pr-Garabato 0.70 0.44 0.07 0.09 11))
            [void]$t.Add((Pr-Recta @(@(0.12, 0.18), @(0.42, 0.32)))); [void]$t.Add((Pr-Recta @(@(0.88, 0.18), @(0.58, 0.32))))
            [void]$t.Add((Pr-Recta @(@(0.26, 0.80), @(0.37, 0.70), @(0.48, 0.80), @(0.59, 0.70), @(0.70, 0.80), @(0.76, 0.74))))
        }
        'susto' {
            [void]$t.Add((Pr-Garabato 0.30 0.36 0.17 0.21 12)); [void]$t.Add((Pr-Garabato 0.70 0.36 0.17 0.21 13))
            [void]$t.Add((Pr-Garabato 0.32 0.40 0.04 0.05 14)); [void]$t.Add((Pr-Garabato 0.68 0.40 0.04 0.05 15))
            [void]$t.Add((Pr-Garabato 0.50 0.78 0.09 0.12 16))
        }
        'mareo' {
            [void]$t.Add((Pr-Recta @(@(0.18, 0.24), @(0.42, 0.54)))); [void]$t.Add((Pr-Recta @(@(0.42, 0.24), @(0.18, 0.54))))
            [void]$t.Add((Pr-Recta @(@(0.58, 0.24), @(0.82, 0.54)))); [void]$t.Add((Pr-Recta @(@(0.82, 0.24), @(0.58, 0.54))))
            $z = @(); for ($i = 0; $i -le 10; $i++) { $z += , @((0.22 + 0.056 * $i), (0.80 + 0.05 * [Math]::Sin($i * 1.3))) }
            [void]$t.Add((Pr-Recta $z))
        }
        'neutra' { [void]$t.Add((Pr-Garabato 0.30 0.40 0.05 0.07 17)); [void]$t.Add((Pr-Garabato 0.70 0.40 0.05 0.07 18)); [void]$t.Add((Pr-Curva 0.28 0.74 0.50 0.76 0.72 0.74 19)) }
        'guino' {
            [void]$t.Add((Pr-Garabato 0.30 0.38 0.12 0.15 20))
            [void]$t.Add((Pr-Recta @(@(0.60, 0.26), @(0.80, 0.38), @(0.60, 0.50))))
            [void]$t.Add((Pr-Curva 0.18 0.62 0.50 0.98 0.82 0.60 21))
        }
        'parpadeo' { [void]$t.Add((Pr-Recta @(@(0.18, 0.40), @(0.42, 0.40)))); [void]$t.Add((Pr-Recta @(@(0.58, 0.40), @(0.82, 0.40)))); [void]$t.Add((Pr-Curva 0.16 0.64 0.50 1.0 0.84 0.64 3)) }
        default { [void]$t.Add((Pr-Garabato 0.30 0.38 0.13 0.16 1)); [void]$t.Add((Pr-Garabato 0.70 0.38 0.13 0.16 2)); [void]$t.Add((Pr-Curva 0.16 0.64 0.50 1.0 0.84 0.64 3)) }
    }
    $script:prCaras[$nombre] = $t
    return $t
}
# dibuja la cara en el lienzo; $prog (0 a 1) = cuánto lleva dibujado. Devuelve la punta del lápiz mientras dibuja.
function Pr-Dibujar-Cara($g, $nombre, $x, $y, $ancho, $alto, $prog, $col) {
    $tr = Pr-Trazos $nombre
    $total = 0; foreach ($s in $tr) { $total += $s.Length }
    $limite = [int][Math]::Ceiling($total * [Math]::Max(0.0, [Math]::Min(1.0, $prog)))
    $pc0 = if ($col) { $col } else { (ARGB 238 22 22 30) }; $pluma = New-Object System.Drawing.Pen($pc0, [float][Math]::Max(1.3, $ancho * 0.03))
    $pluma.LineJoin = 'Round'; $pluma.StartCap = 'Round'; $pluma.EndCap = 'Round'
    $punta = $null
    foreach ($s in $tr) {
        if ($limite -lt 2) { break }
        $n = [Math]::Min($s.Length, $limite); $limite -= $s.Length
        $pts = New-Object 'System.Drawing.PointF[]' $n
        for ($i = 0; $i -lt $n; $i++) { $pts[$i] = New-Object System.Drawing.PointF([float]($x + $s[$i].X * $ancho), [float]($y + $s[$i].Y * $alto)) }
        $g.DrawLines($pluma, $pts)
        $punta = $pts[$n - 1]
    }
    $pluma.Dispose()
    if ($prog -lt 1.0) { return $punta }
    return $null
}
# el lápiz de Painter (la punta en x, y; el cuerpo hacia arriba a la derecha)
function Pr-Lapiz($g, $x, $y, $esc) {
    $st = $g.Save()
    $g.TranslateTransform([float]$x, [float]$y); $g.RotateTransform(-50); $g.ScaleTransform([float]$esc, [float]$esc)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 0 0 0))), 7, 1, 18, 6)
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 240 214 170))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.PointF(6, -3)), (New-Object System.Drawing.PointF(6, 3))))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 30 30 36))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.PointF(2.2, -1.1)), (New-Object System.Drawing.PointF(2.2, 1.1))))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 196 60))), 6, -3, 15, 6)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 170 180))), 21, -3, 2.5, 6)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 240 140 170))), 23.5, -3, 4, 6)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 40 34 30), 0.8)), 6, -3, 21.5, 6)
    $g.Restore($st)
}
# la flecha del ratón (cuando no está dibujando)
function Pr-Flecha($g, $x, $y) {
    $pt = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, [float]$y)), (New-Object System.Drawing.PointF([float]$x, [float]($y + 13))), (New-Object System.Drawing.PointF([float]($x + 3.5), [float]($y + 10))), (New-Object System.Drawing.PointF([float]($x + 6), [float]($y + 15))), (New-Object System.Drawing.PointF([float]($x + 8), [float]($y + 14))), (New-Object System.Drawing.PointF([float]($x + 5.5), [float]($y + 9))), (New-Object System.Drawing.PointF([float]($x + 10), [float]($y + 9))))
    $g.FillPolygon([System.Drawing.Brushes]::White, $pt); $g.DrawPolygon((New-Object System.Drawing.Pen((C 20 20 28), 1)), $pt)
}
# ---- su pantalla: el paisaje (como un dibujo de Paint), $n elementos ----
function Pr-Dibujar-Paisaje($g, $n, $x, $y, $ancho, $alto) {
    if ($n -lt 1) { return }
    $ln = New-Object System.Drawing.Pen((ARGB 200 30 30 40), [float][Math]::Max(1.0, $ancho * 0.012))
    Degradado $g $x $y $ancho $alto (C 120 190 245) (C 214 236 252) 90
    if ($n -ge 2) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 214 70))), [float]($x + 0.68 * $ancho), [float]($y + 0.10 * $alto), [float](0.20 * $ancho), [float](0.20 * $alto))
        $g.DrawEllipse($ln, [float]($x + 0.68 * $ancho), [float]($y + 0.10 * $alto), [float](0.20 * $ancho), [float](0.20 * $alto))
        foreach ($r in 0..7) { $an = $r * [Math]::PI / 4; $cx = $x + 0.78 * $ancho; $cy = $y + 0.20 * $alto; $g.DrawLine($ln, [float]($cx + [Math]::Cos($an) * 0.13 * $ancho), [float]($cy + [Math]::Sin($an) * 0.13 * $alto), [float]($cx + [Math]::Cos($an) * 0.19 * $ancho), [float]($cy + [Math]::Sin($an) * 0.19 * $alto)) }
    }
    if ($n -ge 3) {
        $col = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, [float]($y + 0.78 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.25 * $ancho), [float]($y + 0.60 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.55 * $ancho), [float]($y + 0.76 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.80 * $ancho), [float]($y + 0.58 * $alto))), (New-Object System.Drawing.PointF([float]($x + $ancho), [float]($y + 0.74 * $alto))), (New-Object System.Drawing.PointF([float]($x + $ancho), [float]($y + $alto))), (New-Object System.Drawing.PointF([float]$x, [float]($y + $alto))))
        $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 96 176 92))), $col); $g.DrawPolygon($ln, $col)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 64 146 78))), [float]($x - 0.15 * $ancho), [float]($y + 0.82 * $alto), [float](0.75 * $ancho), [float](0.50 * $alto))
    }
    if ($n -ge 5) {
        $rio = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 0.56 * $ancho), [float]($y + 0.76 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.64 * $ancho), [float]($y + 0.76 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.58 * $ancho), [float]($y + 0.88 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.84 * $ancho), [float]($y + $alto))), (New-Object System.Drawing.PointF([float]($x + 0.50 * $ancho), [float]($y + $alto))), (New-Object System.Drawing.PointF([float]($x + 0.50 * $ancho), [float]($y + 0.90 * $alto))))
        $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 70 140 232))), $rio); $g.DrawPolygon($ln, $rio)
    }
    if ($n -ge 4) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 122 82 50))), [float]($x + 0.20 * $ancho), [float]($y + 0.56 * $alto), [float](0.05 * $ancho), [float](0.22 * $alto))
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 122 60))), [float]($x + 0.12 * $ancho), [float]($y + 0.34 * $alto), [float](0.21 * $ancho), [float](0.30 * $alto))
        $g.DrawEllipse($ln, [float]($x + 0.12 * $ancho), [float]($y + 0.34 * $alto), [float](0.21 * $ancho), [float](0.30 * $alto))
    }
    if ($n -ge 6) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 126 84))), [float]($x + 0.70 * $ancho), [float]($y + 0.60 * $alto), [float](0.17 * $ancho), [float](0.14 * $alto))
        $g.DrawRectangle($ln, [float]($x + 0.70 * $ancho), [float]($y + 0.60 * $alto), [float](0.17 * $ancho), [float](0.14 * $alto))
        $tj = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 0.68 * $ancho), [float]($y + 0.60 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.785 * $ancho), [float]($y + 0.50 * $alto))), (New-Object System.Drawing.PointF([float]($x + 0.89 * $ancho), [float]($y + 0.60 * $alto))))
        $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 176 62 52))), $tj); $g.DrawPolygon($ln, $tj)
        $g.DrawLine($ln, [float]($x + 0.36 * $ancho), [float]($y + 0.22 * $alto), [float]($x + 0.40 * $ancho), [float]($y + 0.18 * $alto)); $g.DrawLine($ln, [float]($x + 0.40 * $ancho), [float]($y + 0.18 * $alto), [float]($x + 0.44 * $ancho), [float]($y + 0.22 * $alto))
        $g.DrawLine($ln, [float]($x + 0.48 * $ancho), [float]($y + 0.14 * $alto), [float]($x + 0.51 * $ancho), [float]($y + 0.11 * $alto)); $g.DrawLine($ln, [float]($x + 0.51 * $ancho), [float]($y + 0.11 * $alto), [float]($x + 0.54 * $ancho), [float]($y + 0.14 * $alto))
        $g.DrawString('Z-779', (FntP('Consolas', 5.5)), (New-Object System.Drawing.SolidBrush((ARGB 200 30 30 40))), [float]($x + 0.06 * $ancho), [float]($y + 0.88 * $alto))
    }
    $ln.Dispose()
}
# ---- lo que dibuja en el lienzo cuando no pinta el paisaje: garabatos de colores, uno detrás de otro ----
# los colores de su paleta (en el mismo orden que en la ventana)
$PrPaleta = @(@(20, 20, 28), @(255, 255, 255), @(128, 128, 136), @(230, 60, 70), @(255, 150, 60), @(255, 214, 70), @(96, 176, 92), @(40, 122, 60), @(120, 190, 245), @(70, 140, 232), @(150, 90, 220), @(240, 140, 190), @(122, 82, 50), @(214, 126, 84))
$PrDibujosLista = @('sol', 'flor', 'gato', 'estrella', 'corazon', 'pez', 'nube', 'arbol', 'casa')
$PrNombresDib = @{ sol = 'un sol'; flor = 'una flor'; gato = 'un gato'; estrella = 'una estrella'; corazon = 'un corazón'; pez = 'un pez'; nube = 'una nube'; arbol = 'un árbol'; casa = 'una casita' }
# los seis huecos del lienzo (esquina de arriba a la izquierda, en proporción del lienzo); cada dibujo mide 0,46 del alto
$PrHuecos = @(@(0.04, 0.03), @(0.36, 0.03), @(0.68, 0.03), @(0.04, 0.51), @(0.36, 0.51), @(0.68, 0.51))
$script:prGarabatos = @{}
function Pr-Color($i) { $c = $PrPaleta[$i]; return [System.Drawing.Color]::FromArgb(240, $c[0], $c[1], $c[2]) }
# los trazos de cada dibujo (en un cuadrado de 0 a 1), cada uno con su color de la paleta
function Pr-Garabatos($nombre) {
    if ($script:prGarabatos.ContainsKey($nombre)) { return $script:prGarabatos[$nombre] }
    $t = New-Object System.Collections.ArrayList
    switch ($nombre) {
        'sol' {
            [void]$t.Add(@{ P = (Pr-Garabato 0.5 0.5 0.2 0.2 31); C = 5 })
            for ($i = 0; $i -lt 8; $i++) { $an = $i * [Math]::PI / 4; [void]$t.Add(@{ P = (Pr-Recta @(@((0.5 + [Math]::Cos($an) * 0.3), (0.5 + [Math]::Sin($an) * 0.3)), @((0.5 + [Math]::Cos($an) * 0.44), (0.5 + [Math]::Sin($an) * 0.44)))); C = 4 }) }
        }
        'flor' {
            [void]$t.Add(@{ P = (Pr-Curva 0.5 0.96 0.47 0.7 0.5 0.46 32); C = 7 })
            [void]$t.Add(@{ P = (Pr-Curva 0.49 0.78 0.66 0.62 0.74 0.74 33); C = 6 })
            for ($i = 0; $i -lt 5; $i++) { $an = $i * 2 * [Math]::PI / 5 - 1.57; [void]$t.Add(@{ P = (Pr-Garabato (0.5 + [Math]::Cos($an) * 0.15) (0.32 + [Math]::Sin($an) * 0.15) 0.09 0.09 (40 + $i)); C = 11 }) }
            [void]$t.Add(@{ P = (Pr-Garabato 0.5 0.32 0.06 0.06 46); C = 5 })
        }
        'gato' {
            [void]$t.Add(@{ P = (Pr-Garabato 0.5 0.58 0.3 0.26 50); C = 2 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.26, 0.42), @(0.28, 0.14), @(0.44, 0.34))); C = 2 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.56, 0.34), @(0.72, 0.14), @(0.74, 0.42))); C = 2 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.39 0.54 0.04 0.05 51); C = 0 }); [void]$t.Add(@{ P = (Pr-Garabato 0.61 0.54 0.04 0.05 52); C = 0 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.46, 0.64), @(0.5, 0.68), @(0.54, 0.64))); C = 11 })
            foreach ($b in @(@(0.12, 0.62, 0.36, 0.66), @(0.12, 0.72, 0.36, 0.7), @(0.88, 0.62, 0.64, 0.66), @(0.88, 0.72, 0.64, 0.7))) { [void]$t.Add(@{ P = (Pr-Recta @(@($b[0], $b[1]), @($b[2], $b[3]))); C = 0 }) }
        }
        'estrella' {
            $pz = @(); for ($i = 0; $i -le 10; $i++) { $an = -1.5708 + $i * [Math]::PI / 5; $rr = if ($i % 2 -eq 0) { 0.44 } else { 0.18 }; $pz += , @((0.5 + [Math]::Cos($an) * $rr), (0.54 + [Math]::Sin($an) * $rr)) }
            [void]$t.Add(@{ P = (Pr-Recta $pz); C = 5 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.5 0.55 0.06 0.06 53); C = 4 })
        }
        'corazon' {
            $pz = @(); for ($i = 0; $i -le 40; $i++) { $q = $i / 40.0 * 2 * [Math]::PI; $hx = 16 * [Math]::Pow([Math]::Sin($q), 3); $hy = 13 * [Math]::Cos($q) - 5 * [Math]::Cos(2 * $q) - 2 * [Math]::Cos(3 * $q) - [Math]::Cos(4 * $q); $pz += , @((0.5 + $hx / 38.0), (0.47 - $hy / 38.0)) }
            [void]$t.Add(@{ P = (Pr-Recta $pz); C = 3 })
            [void]$t.Add(@{ P = (Pr-Curva 0.32 0.32 0.36 0.24 0.42 0.26 54); C = 1 })
        }
        'pez' {
            [void]$t.Add(@{ P = (Pr-Garabato 0.44 0.5 0.28 0.17 55); C = 8 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.7, 0.5), @(0.92, 0.32), @(0.9, 0.68), @(0.7, 0.5))); C = 9 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.3 0.46 0.03 0.03 56); C = 0 })
            [void]$t.Add(@{ P = (Pr-Curva 0.44 0.38 0.4 0.5 0.44 0.62 57); C = 9 })
        }
        'nube' {
            [void]$t.Add(@{ P = (Pr-Garabato 0.32 0.56 0.16 0.13 58); C = 8 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.52 0.44 0.18 0.16 59); C = 8 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.7 0.58 0.15 0.12 60); C = 8 })
            foreach ($x in @(0.36, 0.52, 0.68)) { [void]$t.Add(@{ P = (Pr-Recta @(@($x, 0.78), @(($x - 0.03), 0.92))); C = 9 }) }
        }
        'arbol' {
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.45, 0.95), @(0.46, 0.58))); C = 12 }); [void]$t.Add(@{ P = (Pr-Recta @(@(0.55, 0.95), @(0.54, 0.58))); C = 12 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.5 0.38 0.3 0.26 61); C = 7 })
            [void]$t.Add(@{ P = (Pr-Garabato 0.38 0.32 0.04 0.04 62); C = 3 }); [void]$t.Add(@{ P = (Pr-Garabato 0.62 0.42 0.04 0.04 63); C = 3 })
        }
        'casa' {
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.18, 0.5), @(0.18, 0.92), @(0.82, 0.92), @(0.82, 0.5), @(0.18, 0.5))); C = 13 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.1, 0.52), @(0.5, 0.14), @(0.9, 0.52))); C = 3 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.42, 0.92), @(0.42, 0.68), @(0.58, 0.68), @(0.58, 0.92))); C = 12 })
            [void]$t.Add(@{ P = (Pr-Recta @(@(0.26, 0.6), @(0.36, 0.6), @(0.36, 0.7), @(0.26, 0.7), @(0.26, 0.6))); C = 9 })
        }
    }
    $script:prGarabatos[$nombre] = $t
    return $t
}
# los puntos de un dibujo ya colocados en el lienzo (se calculan una vez; el lienzo se mueve con TranslateTransform)
function Pr-Dibujo-Cache($d, $lw, $lh) {
    if ($d.Cache -and $d.CW -eq $lw -and $d.CH -eq $lh) { return , $d.Cache }
    $tam = if ($d.Tam) { $d.Tam } else { 0.46 }
    $lado = $lh * $tam; $ox = $lw * $d.SX; $oy = $lh * $d.SY
    $lista = New-Object System.Collections.ArrayList
    foreach ($tr in (Pr-Garabatos $d.N)) {
        $src = $tr.P; $pts = New-Object 'System.Drawing.PointF[]' $src.Length
        for ($i = 0; $i -lt $src.Length; $i++) { $pts[$i] = New-Object System.Drawing.PointF([float]($ox + $src[$i].X * $lado), [float]($oy + $src[$i].Y * $lado)) }
        [void]$lista.Add(@{ P = $pts; C = $tr.C })
    }
    $d.Cache = $lista; $d.CW = $lw; $d.CH = $lh
    return , $lista
}
# dibuja un garabato hasta donde va ($prog de 0 a 1); mientras dibuja devuelve la punta del lápiz y el color que usa
function Pr-Dibujar-Dibujo($g, $d, $lx, $ly, $lw, $lh, $prog) {
    $cache = Pr-Dibujo-Cache $d $lw $lh
    $total = 0; foreach ($s in $cache) { $total += $s.P.Length }
    $limite = [int][Math]::Ceiling($total * [Math]::Max(0.0, [Math]::Min(1.0, $prog)))
    $tam = if ($d.Tam) { $d.Tam } else { 0.46 }
    $gros = [float][Math]::Max(1.4, $lh * $tam * 0.04)
    $st = $g.Save(); $g.TranslateTransform([float]$lx, [float]$ly)
    $res = $null
    foreach ($s in $cache) {
        if ($limite -lt 2) { break }
        $n = [Math]::Min($s.P.Length, $limite); $limite -= $s.P.Length
        if ($n -eq $s.P.Length) { $pts = $s.P } else { $pts = New-Object 'System.Drawing.PointF[]' $n; [Array]::Copy($s.P, $pts, $n) }
        $pen = New-Object System.Drawing.Pen((Pr-Color $s.C), $gros); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
        $g.DrawLines($pen, $pts); $pen.Dispose()
        $res = @{ X = $lx + $pts[$n - 1].X; Y = $ly + $pts[$n - 1].Y; C = $s.C }
    }
    $g.Restore($st)
    if ($prog -lt 1.0) { return $res }
    return $null
}
# empieza un dibujo nuevo en un hueco libre
function Pr-Nuevo-Dibujo {
    $e = $script:pr; $ahora = [Environment]::TickCount
    $usados = @($e.Dib | ForEach-Object { $_.Hueco }); $libres = @(0..5 | Where-Object { $usados -notcontains $_ })
    if ($libres.Count -eq 0) { return }
    $nombres = @($e.Dib | ForEach-Object { $_.N }); $opc = @($PrDibujosLista | Where-Object { $nombres -notcontains $_ })
    $hu = $libres[$Rnd.Next($libres.Count)]; $nom = $opc[$Rnd.Next($opc.Count)]
    [void]$e.Dib.Add(@{ N = $nom; Hueco = $hu; SX = $PrHuecos[$hu][0]; SY = $PrHuecos[$hu][1]; T0 = $ahora })
    $e.DibProx = $ahora + $PrTiempos.DibujoMs + 4500 + $Rnd.Next(0, 4000)
    Sonido 'garabato'
    if ($Rnd.Next(100) -lt 22 -and -not (Pr-Voz-Suena) -and $script:skin.Garabato) { Decir ((Azar $script:skin.Garabato) -f $PrNombresDib[$nom]) }
}
# la goma de borrar (cuando limpia el lienzo)
function Pr-Goma($g, $x, $y, $esc) {
    $st = $g.Save()
    $g.TranslateTransform([float]$x, [float]$y); $g.RotateTransform(-30); $g.ScaleTransform([float]$esc, [float]$esc)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 240 140 170))), -6, -4, 12, 8)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 160 230))), 2, -4, 6, 8)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 40 34 50), 0.8)), -6, -4, 14, 8)
    $g.Restore($st)
}

# dónde está su ventana ahora mismo: lienzo, pantallita de la cara, panel, barra de estado (en píxeles de la escena)
function Pr-Geometria {
    $a = $script:actores['P']; if (-not $a) { return $null }
    $img = $a.Imgs[$a.Pose]; if (-not $img) { return $null }
    $r = $a.Rect; $esc = [Math]::Min($r[2] / $img.Width, $r[3] / $img.Height)
    $iw = $img.Width * $esc; $ih = $img.Height * $esc
    $ix = $r[0] + ($r[2] - $iw) / 2 + $a.OX; $iy = $r[1] + $r[3] - $ih + $a.OY
    return @{ X = $ix; Y = $iy; S = $iw / 340.0
        CX = $ix + $iw * $PrCanvas[0]; CY = $iy + $ih * $PrCanvas[2]; CW = $iw * ($PrCanvas[1] - $PrCanvas[0]); CH = $ih * ($PrCanvas[3] - $PrCanvas[2])
        PX = $ix + $iw * $PrPanel[0]; PY = $iy + $ih * $PrPanel[2]; PW = $iw * ($PrPanel[1] - $PrPanel[0]); PH = $ih * ($PrPanel[3] - $PrPanel[2]) }
}
# ---- su cara viva: cada expresión = ojos, cejas, boca y un extra. Mira al lápiz o a tu ratón, parpadea y mueve
#      la boca mientras habla. (Las caras viejas de Pr-Trazos ya no se usan en la pantallita.) ----
$PrExpresiones = @{
    feliz = @('abiertos', '', 'sonrisa', ''); contento = @('felices', '', 'gran', 'rubor'); risa = @('felices', '', 'risa', '')
    sorpresa = @('grandes', 'alzadas', 'o', 'exclamacion'); triste = @('abiertos', 'tristes', 'triste', ''); llora = @('cerrados', 'tristes', 'ondulada', 'lagrimas')
    enfado = @('abiertos', 'enfado', 'dientes', ''); furioso = @('pequenos', 'enfado', 'dientes', 'vapor'); susto = @('grandes', 'tristes', 'ondulada', 'gota')
    nervioso = @('abiertos', 'tristes', 'ondulada', 'gota'); mareo = @('espiral', '', 'ondulada', ''); neutra = @('abiertos', '', 'recta', '')
    guino = @('guino', '', 'lengua', ''); aburrido = @('medio', '', 'recta', ''); pensando = @('arriba', 'alzada', 'lado', 'interrogacion')
    enamorado = @('corazon', '', 'gato', 'rubor'); orgulloso = @('felices', '', 'gran', 'brillos'); concentrado = @('abiertos', '', 'lengua', '')
    dormido = @('cerrados', '', 'o', 'zzz'); silbando = @('felices', '', 'silbar', 'notas'); curioso = @('abiertos', 'alzada', 'o', '')
}
$PrNombresExpr = @{ feliz = 'feliz'; contento = 'contento'; risa = 'muerto de risa'; sorpresa = '¡sorpresa!'; triste = 'triste'; llora = 'llorando'; enfado = 'enfadado'
    furioso = 'furioso'; susto = 'asustado'; nervioso = 'nervioso'; mareo = 'mareado'; neutra = 'tranquilo'; guino = 'pillín'; aburrido = 'aburrido'; pensando = 'pensando'
    enamorado = 'enamorado'; orgulloso = 'orgulloso'; concentrado = 'concentrado'; dormido = 'dormido'; silbando = 'silbando'; curioso = 'curioso' }
$PrHumores = @('feliz', 'feliz', 'contento', 'silbando', 'pensando', 'aburrido', 'curioso', 'neutra', 'risa', 'enamorado', 'feliz')
function Pr-PF($a, $b) { return New-Object System.Drawing.PointF([float]$a, [float]$b) }
# relieve de los programas de antes (claro arriba a la izquierda, oscuro abajo a la derecha; al revés si está hundido)
function Pr-Bisel($g, $x, $y, $ancho, $alto, $hundido) {
    $a = if ($hundido) { (C 128 128 128) } else { (C 255 255 255) }; $b = if ($hundido) { (C 255 255 255) } else { (C 128 128 128) }
    $pa = New-Object System.Drawing.Pen($a, 1); $pb = New-Object System.Drawing.Pen($b, 1)
    $g.DrawLine($pa, [float]$x, [float]$y, [float]($x + $ancho), [float]$y); $g.DrawLine($pa, [float]$x, [float]$y, [float]$x, [float]($y + $alto))
    $g.DrawLine($pb, [float]$x, [float]($y + $alto), [float]($x + $ancho), [float]($y + $alto)); $g.DrawLine($pb, [float]($x + $ancho), [float]$y, [float]($x + $ancho), [float]($y + $alto))
    $pa.Dispose(); $pb.Dispose()
}
# la herramienta $t de la caja (2 columnas), marcada como pulsada
function Pr-Herramienta($g, $wx, $wy, $es, $t) {
    $col = $t % 2; $fil = [Math]::Floor($t / 2)
    $hx = $wx + (4 + $col * 11) * $es; $hy = $wy + (27 + $fil * 11) * $es; $hl = 11 * $es
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 255 255 255))), [float]$hx, [float]$hy, [float]$hl, [float]$hl)
    Pr-Bisel $g $hx $hy $hl $hl $true
}
function Pr-Jit($rn, $m) { return ($rn.NextDouble() - 0.5) * 2 * $m }
# un círculo garabateado: varias vueltas torcidas, como hecho con el ratón
function Pr-GE($g, $pen, $cx, $cy, $rx, $ry, $sem, $vueltas) {
    $rn = New-Object System.Random $sem; $n = [int](20 * $vueltas); $pts = New-Object 'System.Drawing.PointF[]' ($n + 1)
    $a0 = $rn.NextDouble() * 6.28; $jj = [Math]::Max($rx, $ry) * 0.16
    for ($i = 0; $i -le $n; $i++) { $an = $a0 + $i / 20.0 * 6.2832; $f = 1.0 + 0.12 * [Math]::Sin($i * 0.8 + $sem) - 0.08 * $i / $n; $pts[$i] = Pr-PF ($cx + [Math]::Cos($an) * $rx * $f + (Pr-Jit $rn $jj)) ($cy + [Math]::Sin($an) * $ry * $f + (Pr-Jit $rn $jj)) }
    $g.DrawCurve($pen, $pts, 0.5)
}
# una línea temblona que pasa por los puntos @(@(x, y), ...)
function Pr-GL($g, $pen, $lista, $sem, $jj) {
    $rn = New-Object System.Random $sem; $pl = New-Object System.Collections.ArrayList
    for ($s = 0; $s -lt $lista.Count - 1; $s++) { $p0 = $lista[$s]; $p1 = $lista[$s + 1]; for ($i = 0; $i -lt 4; $i++) { $q = $i / 4.0; [void]$pl.Add((Pr-PF ($p0[0] + ($p1[0] - $p0[0]) * $q + (Pr-Jit $rn $jj)) ($p0[1] + ($p1[1] - $p0[1]) * $q + (Pr-Jit $rn $jj)))) } }
    $ul = $lista[$lista.Count - 1]; [void]$pl.Add((Pr-PF ($ul[0] + (Pr-Jit $rn $jj)) ($ul[1] + (Pr-Jit $rn $jj))))
    $g.DrawCurve($pen, [System.Drawing.PointF[]]$pl.ToArray(), 0.5)
}
# un arco temblón (ángulos en grados; 0 = derecha, 90 = abajo)
function Pr-GArco($g, $pen, $cx, $cy, $rx, $ry, $a0, $a1, $sem, $jj) {
    $lista = @(); for ($i = 0; $i -le 6; $i++) { $an = ($a0 + ($a1 - $a0) * $i / 6.0) * [Math]::PI / 180; $lista += , @(($cx + [Math]::Cos($an) * $rx), ($cy + [Math]::Sin($an) * $ry)) }
    Pr-GL $g $pen $lista $sem $jj
}
# un borrón relleno (pupilas, bocas)
function Pr-GBlob($g, $br, $cx, $cy, $rx, $ry, $sem) {
    $rn = New-Object System.Random $sem; $pts = New-Object 'System.Drawing.PointF[]' 10
    for ($i = 0; $i -lt 10; $i++) { $an = $i / 10.0 * 6.2832; $f = 0.8 + $rn.NextDouble() * 0.35; $pts[$i] = Pr-PF ($cx + [Math]::Cos($an) * $rx * $f) ($cy + [Math]::Sin($an) * $ry * $f) }
    $g.FillClosedCurve($br, $pts, [System.Drawing.Drawing2D.FillMode]::Winding, 0.5)
}
function Pr-Cara-Viva($g, $expr, $x, $y, $ancho, $alto, $mira, $habla, $cierra, $brillo) {
    if ($brillo) { return }
    $def = $PrExpresiones[$expr]; if (-not $def) { $def = $PrExpresiones['feliz'] }
    $ojos = $def[0]; $cejas = $def[1]; $boca = $def[2]; $extra = $def[3]
    $t = [Environment]::TickCount
    $u = [Math]::Min([double]$ancho, $alto * 1.3); $hh = $u / 1.3
    $ox = $x + ($ancho - $u) / 2; $oy = $y + ($alto - $hh) / 2
    # el trazo "tiembla": tres versiones del dibujo que se van alternando
    $sb = ([Math]::Abs(([string]$expr).GetHashCode()) % 10000) + ([int]($t / 170) % 3) * 977
    $tinta = C 18 16 24
    $pen = New-Object System.Drawing.Pen($tinta, [float][Math]::Max(1.5, $u * 0.04)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $pen2 = New-Object System.Drawing.Pen((ARGB 170 18 16 24), [float][Math]::Max(1.0, $u * 0.02)); $pen2.StartCap = 'Round'; $pen2.EndCap = 'Round'
    $neg = New-Object System.Drawing.SolidBrush($tinta); $bla = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $fBo = New-Object System.Drawing.SolidBrush((C 120 30 50)); $fRo = New-Object System.Drawing.SolidBrush((C 245 110 150))
    $jj = $u * 0.012
    $dx = 0.0; $dy = 0.0; if ($mira) { $dx = [double]$mira[0]; $dy = [double]$mira[1] }
    if ($ojos -eq 'arriba') { $ojos = 'abiertos'; $dx = 0.45; $dy = -0.9 }
    if ($cierra -and @('abiertos', 'grandes', 'pequenos', 'medio') -contains $ojos) { $ojos = 'cerrados' }
    $rx = $u * 0.11; $ry = $hh * 0.19; $ey = $oy + $hh * 0.4
    $ex = @(($ox + $u * 0.32 + (($sb % 5) - 2) * 0.4), ($ox + $u * 0.68))
    # ---- ojos ----
    for ($k = 0; $k -lt 2; $k++) {
        $cx = $ex[$k]; $tipo = $ojos; $sk = $sb + $k * 53
        if ($ojos -eq 'guino') { $tipo = if ($k -eq 0) { 'abiertos' } else { 'pillo' } }
        if (@('abiertos', 'grandes', 'pequenos', 'medio') -contains $tipo) {
            $f = if ($tipo -eq 'grandes') { 1.22 } elseif ($tipo -eq 'pequenos') { 0.85 } else { 1.0 }
            $ew = $rx * $f * (1 + ($k * 0.06)); $eh = $ry * $f
            Pr-GE $g $pen $cx $ey $ew $eh $sk 2.2
            Pr-GE $g $pen2 $cx $ey ($ew * 0.95) ($eh * 0.95) ($sk + 7) 1.0
            $pf = if ($tipo -eq 'grandes') { 0.38 } elseif ($tipo -eq 'pequenos') { 0.25 } else { 0.5 }
            $pr = $ew * $pf
            $pdy = if ($tipo -eq 'medio') { 0.55 } else { $dy }
            $px = $cx + $dx * ($ew - $pr) * 0.7; $py = $ey + $pdy * ($eh - $pr) * 0.7
            Pr-GBlob $g $neg $px $py $pr ($pr * 1.15) ($sk + 3)
            if ($tipo -eq 'medio') {
                Pr-GL $g $pen @(@(($cx - $ew * 1.1), ($ey - $eh * 0.05)), @(($cx + $ew * 1.1), ($ey + $eh * 0.05))) ($sk + 9) $jj
                Pr-GL $g $pen2 @(@(($cx - $ew * 0.7), ($ey - $eh * 0.5)), @(($cx - $ew * 0.2), ($ey - $eh * 0.15)), @(($cx + $ew * 0.2), ($ey - $eh * 0.7)), @(($cx + $ew * 0.7), ($ey - $eh * 0.2))) ($sk + 11) $jj
            }
        }
        elseif ($tipo -eq 'felices') { Pr-GArco $g $pen $cx ($ey + $ry * 0.35) $rx ($ry * 0.9) 195 345 $sk $jj }
        elseif ($tipo -eq 'cerrados') { Pr-GArco $g $pen $cx ($ey - $ry * 0.35) $rx ($ry * 0.7) 15 165 $sk $jj }
        elseif ($tipo -eq 'pillo') { Pr-GL $g $pen @(@(($cx + $rx * 0.9), ($ey - $ry * 0.7)), @(($cx - $rx * 0.8), $ey), @(($cx + $rx * 0.9), ($ey + $ry * 0.7))) $sk $jj }
        elseif ($tipo -eq 'espiral') {
            $lista = @(); $gi = $t / 160.0 * $(if ($k -eq 0) { 1 } else { -1 })
            for ($i = 0; $i -lt 18; $i++) { $an = $gi + $i * 0.75; $rr = $i / 17.0; $lista += , @(($cx + [Math]::Cos($an) * $rx * $rr), ($ey + [Math]::Sin($an) * $ry * $rr)) }
            Pr-GL $g $pen2 $lista $sk ($jj * 0.6)
        }
        elseif ($tipo -eq 'corazon') {
            $lat = 1.05 + 0.12 * [Math]::Abs([Math]::Sin($t / 220.0))
            $pts = New-Object 'System.Drawing.PointF[]' 20
            for ($i = 0; $i -lt 20; $i++) { $q = $i / 20.0 * 2 * [Math]::PI; $hx = 16 * [Math]::Pow([Math]::Sin($q), 3); $hy = 13 * [Math]::Cos($q) - 5 * [Math]::Cos(2 * $q) - 2 * [Math]::Cos(3 * $q) - [Math]::Cos(4 * $q); $pts[$i] = Pr-PF ($cx + $hx / 16.0 * $rx * $lat) ($ey - $hy / 16.0 * $ry * $lat) }
            $g.FillPolygon($fRo, $pts); $g.DrawPolygon($pen2, $pts)
        }
    }
    # ---- cejas ----
    $by = $ey - $ry * 1.5
    if ($cejas -eq 'enfado') { Pr-GL $g $pen @(@(($ex[0] - $rx), ($by - $ry * 0.15)), @(($ex[0] + $rx * 0.9), ($by + $ry * 0.45))) ($sb + 21) $jj; Pr-GL $g $pen @(@(($ex[1] + $rx), ($by - $ry * 0.15)), @(($ex[1] - $rx * 0.9), ($by + $ry * 0.45))) ($sb + 22) $jj }
    elseif ($cejas -eq 'tristes') { Pr-GL $g $pen @(@(($ex[0] - $rx), ($by + $ry * 0.35)), @(($ex[0] + $rx * 0.9), ($by - $ry * 0.2))) ($sb + 23) $jj; Pr-GL $g $pen @(@(($ex[1] + $rx), ($by + $ry * 0.35)), @(($ex[1] - $rx * 0.9), ($by - $ry * 0.2))) ($sb + 24) $jj }
    elseif ($cejas -eq 'alzadas') { $kk = 0; foreach ($cx in $ex) { Pr-GArco $g $pen $cx ($by + $ry * 0.2) ($rx * 0.9) ($ry * 0.5) 200 340 ($sb + 25 + $kk) $jj; $kk++ } }
    elseif ($cejas -eq 'alzada') { Pr-GArco $g $pen $ex[0] ($by + $ry * 0.1) ($rx * 0.9) ($ry * 0.5) 200 340 ($sb + 27) $jj; Pr-GL $g $pen @(@(($ex[1] - $rx * 0.85), ($by + $ry * 0.2)), @(($ex[1] + $rx * 0.85), ($by + $ry * 0.25))) ($sb + 28) $jj }
    # ---- boca (si habla, se abre y se cierra) ----
    $mx = $ox + $u * 0.5; $my = $oy + $hh * 0.78; $mw = $u * 0.21
    if ($habla -gt 0.05 -and @('sonrisa', 'gran', 'recta', 'triste', 'ondulada', 'gato', 'lado', 'lengua') -contains $boca) {
        $ma = $hh * (0.03 + 0.08 * $habla); $mww = $mw * (0.55 + 0.2 * $habla)
        Pr-GBlob $g $fBo $mx $my $mww $ma ($sb + 31)
        Pr-GE $g $pen $mx $my $mww $ma ($sb + 32) 1.3
    } else {
        switch ($boca) {
            'sonrisa' { Pr-GArco $g $pen $mx ($my - $hh * 0.1) $mw ($hh * 0.14) 15 165 ($sb + 33) $jj; Pr-GArco $g $pen2 ($mx + 1) ($my - $hh * 0.09) ($mw * 0.95) ($hh * 0.13) 20 160 ($sb + 34) $jj }
            { $_ -eq 'gran' -or $_ -eq 'risa' } {
                $fx = if ($_ -eq 'risa') { 1.25 } else { 1.05 }; $fy = if ($_ -eq 'risa') { 0.15 } else { 0.11 }
                Pr-GBlob $g $fBo $mx ($my - $hh * 0.02) ($mw * $fx) ($hh * $fy) ($sb + 35)
                Pr-GBlob $g $fRo ($mx + $mw * 0.15) ($my + $hh * $fy * 0.45) ($mw * 0.45) ($hh * $fy * 0.4) ($sb + 36)
                Pr-GArco $g $pen $mx ($my - $hh * 0.07) ($mw * $fx * 1.02) ($hh * $fy * 1.5) 5 175 ($sb + 37) $jj
                Pr-GL $g $pen @(@(($mx - $mw * $fx), ($my - $hh * 0.06)), @(($mx + $mw * $fx), ($my - $hh * 0.08))) ($sb + 38) $jj
            }
            'o' { $s = $hh * (0.07 + 0.012 * [Math]::Sin($t / 300.0)); Pr-GBlob $g $fBo $mx $my ($s * 0.8) $s ($sb + 39); Pr-GE $g $pen $mx $my ($s * 0.85) ($s * 1.05) ($sb + 40) 1.6 }
            'recta' { Pr-GL $g $pen @(@(($mx - $mw * 0.7), $my), @(($mx + $mw * 0.7), ($my + $hh * 0.02))) ($sb + 41) $jj }
            'lado' { Pr-GL $g $pen @(@(($mx - $mw * 0.1), ($my + $hh * 0.03)), @(($mx + $mw * 0.45), $my), @(($mx + $mw * 0.85), ($my - $hh * 0.05))) ($sb + 42) $jj }
            'triste' { Pr-GArco $g $pen $mx ($my + $hh * 0.1) ($mw * 0.85) ($hh * 0.12) 200 340 ($sb + 43) $jj }
            'ondulada' { $lista = @(); for ($i = 0; $i -le 6; $i++) { $lista += , @(($mx - $mw + $i * $mw / 3.0), ($my + $(if ($i % 2) { -1 } else { 1 }) * $hh * 0.035)) }; Pr-GL $g $pen $lista ($sb + 44) ($jj * 0.6) }
            'gato' { Pr-GArco $g $pen ($mx - $mw * 0.25) ($my - $hh * 0.02) ($mw * 0.25) ($hh * 0.07) 0 180 ($sb + 45) $jj; Pr-GArco $g $pen ($mx + $mw * 0.25) ($my - $hh * 0.02) ($mw * 0.25) ($hh * 0.07) 0 180 ($sb + 46) $jj }
            'lengua' {
                Pr-GBlob $g $fRo ($mx + $mw * 0.4) ($my + $hh * 0.04) ($mw * 0.25) ($hh * 0.07) ($sb + 47)
                Pr-GE $g $pen2 ($mx + $mw * 0.4) ($my + $hh * 0.04) ($mw * 0.25) ($hh * 0.07) ($sb + 48) 1.0
                Pr-GArco $g $pen $mx ($my - $hh * 0.1) $mw ($hh * 0.14) 15 165 ($sb + 49) $jj
            }
            'dientes' {
                $g.FillRectangle($bla, [float]($mx - $mw), [float]($my - $hh * 0.065), [float](2 * $mw), [float]($hh * 0.13))
                Pr-GL $g $pen @(@(($mx - $mw), ($my - $hh * 0.065)), @(($mx + $mw), ($my - $hh * 0.07)), @(($mx + $mw), ($my + $hh * 0.065)), @(($mx - $mw), ($my + $hh * 0.065)), @(($mx - $mw), ($my - $hh * 0.065))) ($sb + 50) $jj
                Pr-GL $g $pen2 @(@(($mx - $mw), $my), @(($mx + $mw), $my)) ($sb + 51) $jj
                foreach ($q in @(-0.5, 0, 0.5)) { Pr-GL $g $pen2 @(@(($mx + $q * $mw), ($my - $hh * 0.06)), @(($mx + $q * $mw), ($my + $hh * 0.06))) ($sb + 52 + [int]($q * 4)) ($jj * 0.5) }
            }
            'silbar' { Pr-GBlob $g $fBo ($mx + $mw * 0.3) $my ($hh * 0.04) ($hh * 0.045) ($sb + 55); Pr-GE $g $pen ($mx + $mw * 0.3) $my ($hh * 0.045) ($hh * 0.05) ($sb + 56) 1.4 }
        }
    }
    # ---- extras ----
    $fs = [float][Math]::Max(5.0, $hh * 0.17)
    switch ($extra) {
        'rubor' { $rb = New-Object System.Drawing.Pen((ARGB 150 245 100 140), [float]($u * 0.015)); $kk = 0; foreach ($cx in $ex) { for ($i = 0; $i -lt 3; $i++) { Pr-GL $g $rb @(@(($cx - $rx * 0.7 + $i * $rx * 0.45), ($ey + $ry * 1.5)), @(($cx - $rx * 0.45 + $i * $rx * 0.45), ($ey + $ry * 1.1))) ($sb + 60 + $kk * 5 + $i) ($jj * 0.4) } ; $kk++ }; $rb.Dispose() }
        'gota' { $gy = ($t / 25.0) % ($hh * 0.3); $gb = New-Object System.Drawing.SolidBrush((C 90 160 240)); Pr-GBlob $g $gb ($ox + $u * 0.87) ($oy + $hh * 0.15 + $gy) ($u * 0.025) ($hh * 0.05) ($sb + 70); $gb.Dispose() }
        'lagrimas' { $gb = New-Object System.Drawing.SolidBrush((C 90 160 240)); foreach ($cx in $ex) { $gy = (($t / 14.0) + $cx) % ($hh * 0.42); Pr-GBlob $g $gb $cx ($ey + $ry * 0.8 + $gy) ($u * 0.02) ($hh * 0.035) ($sb + 71) }; $gb.Dispose() }
        'zzz' { for ($i = 0; $i -lt 3; $i++) { $fa = (($t / 1300.0) + $i / 3.0) % 1.0; $g.DrawString('z', (FntP('Comic Sans MS', ($fs * 0.5 + $fa * $fs * 0.4), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((ARGB ([int](230 * (1 - $fa))) 18 16 24))), [float]($ox + $u * 0.78 + $fa * $u * 0.1), [float]($oy + $hh * 0.3 - $fa * $hh * 0.35)) } }
        'interrogacion' { $g.DrawString('?', (FntP('Comic Sans MS', ($fs * 0.9), [System.Drawing.FontStyle]::Bold)), $neg, [float]($ox + $u * 0.84), [float]($oy - $hh * 0.05 + [Math]::Sin($t / 400.0) * 2)) }
        'exclamacion' { $g.DrawString('!', (FntP('Comic Sans MS', ($fs * 0.9), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 220 40 40))), [float]($ox + $u * 0.86), [float]($oy - $hh * 0.07)) }
        'notas' { for ($i = 0; $i -lt 2; $i++) { $fa = (($t / 1500.0) + $i / 2.0) % 1.0; $g.DrawString('♪', (FntP('Segoe UI Symbol', ($fs * 0.65))), (New-Object System.Drawing.SolidBrush((ARGB ([int](230 * (1 - $fa))) 18 16 24))), [float]($ox + $u * 0.66 + $fa * $u * 0.2), [float]($oy + $hh * 0.62 - $fa * $hh * 0.5)) } }
        'vapor' { $vp = New-Object System.Drawing.Pen((ARGB 200 200 60 40), [float]($u * 0.018)); for ($i = 0; $i -lt 3; $i++) { $lista = @(); for ($j2 = 0; $j2 -lt 5; $j2++) { $lista += , @(($ox + $u * (0.3 + 0.2 * $i) + [Math]::Sin($j2 * 1.4 + $t / 120.0) * $u * 0.025), ($oy + $hh * 0.12 - $j2 * $hh * 0.03)) }; Pr-GL $g $vp $lista ($sb + 80 + $i) ($jj * 0.3) }; $vp.Dispose() }
        'brillos' { foreach ($b in @(@(0.1, 0.15, 0), @(0.9, 0.2, 1.7), @(0.86, 0.75, 3.1))) { $a2 = [int](140 + 110 * [Math]::Abs([Math]::Sin($t / 400.0 + $b[2]))); $g.DrawString('✦', (FntP('Segoe UI Symbol', ($fs * 0.55))), (New-Object System.Drawing.SolidBrush((ARGB $a2 230 170 0))), [float]($ox + $u * $b[0] - $fs * 0.3), [float]($oy + $hh * $b[1] - $fs * 0.3)) } }
    }
    $pen.Dispose(); $pen2.Dispose(); $neg.Dispose(); $bla.Dispose(); $fBo.Dispose(); $fRo.Dispose()
}

# los dibujos de cara hechos a mano (skins\painter\caras\<expresión>.png); se cargan una vez y se recuerdan
$script:prCarasImg = @{}
function Pr-Cara-Img($nombre) {
    if ($script:prCarasImg.ContainsKey($nombre)) { return $script:prCarasImg[$nombre] }
    $img = Cargar-Img ('skins\painter\caras\' + $nombre + '.png')
    # un lienzo todavía en blanco no cuenta: se sigue usando la cara dibujada por código
    if ($img) { $vacio = $true; $bm = New-Object System.Drawing.Bitmap($img); for ($yy = 0; $yy -lt $bm.Height -and $vacio; $yy += 5) { for ($xx = 0; $xx -lt $bm.Width; $xx += 5) { $px = $bm.GetPixel($xx, $yy); if ($px.A -gt 30 -and ($px.R -lt 235 -or $px.G -lt 235 -or $px.B -lt 235)) { $vacio = $false; break } } }; $bm.Dispose(); if ($vacio) { $img.Dispose(); $img = $null } }
    $script:prCarasImg[$nombre] = $img
    return $img
}
# su cara en la pantallita: en blanco, como un lienzo, con trazos de lápiz repasados (no quedan lisos)
function Pr-Pintar-Cara($g, $nombre, $x, $y, $ancho, $alto, $prog, $mira, $habla, $cierra) {
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$ancho, [float]$alto)))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 252 251 247))), [float]$x, [float]$y, [float]$ancho, [float]$alto)
    $pp = New-Object System.Drawing.Pen((ARGB 16 120 110 90), 1); for ($yy = $y + 1; $yy -lt $y + $alto; $yy += 3) { $g.DrawLine($pp, [float]$x, [float]$yy, [float]($x + $ancho), [float]$yy) }; $pp.Dispose()
    $esc = 0.82 + 0.18 * [Math]::Min(1.0, [Math]::Max(0.0, [double]$prog)); if ($null -eq $prog) { $esc = 1.0 }
    $st = $g.Save()
    $cxm = $x + $ancho / 2; $cym = $y + $alto / 2
    $g.TranslateTransform([float]$cxm, [float]$cym); $g.ScaleTransform([float]$esc, [float]$esc); $g.TranslateTransform([float](-$cxm), [float](-$cym))
    # garabato hecho con el ratón: trazos temblones que se redibujan solos
    # si hay un dibujo hecho a mano en skins\painter\caras, se usa ese (con su versión hablando o parpadeando si existe)
    $img = $null
    if ($habla -gt 0.5) { $img = Pr-Cara-Img ($nombre + '_habla') }
    if (-not $img -and $cierra) { $img = Pr-Cara-Img ($nombre + '_parpadeo') }
    if (-not $img) { $img = Pr-Cara-Img $nombre }
    if ($img) {
        $esc2 = [Math]::Min($ancho / $img.Width, $alto / $img.Height); $iw = $img.Width * $esc2; $ih = $img.Height * $esc2
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($img, [float]($x + ($ancho - $iw) / 2), [float]($y + ($alto - $ih) / 2), [float]$iw, [float]$ih)
    } else { Pr-Cara-Viva $g $nombre $x $y $ancho $alto $mira $habla $cierra $false }
    $g.Restore($st)
    $g.ResetClip()
}# ---- el panel al estilo de los programas de dibujo de antes (fondo guardado) ----
function Pr-Pintar-Fondo($g, $W, $H) {
    $g.Clear((C 192 192 192))
    # la barra de arriba, azul como una barra de título
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, 52)), (C 0 0 128), (C 16 132 208), 0)
    $g.FillRectangle($br, 0, 0, $W, 52); $br.Dispose()
    $g.DrawLine((New-Object System.Drawing.Pen((C 255 255 255), 1)), 0, 52, $W, 52)
    # el marco de los botones, hundido
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 192 192 192))), 8, 60, 394, ($H - 66))
    Pr-Bisel $g 8 60 394 ($H - 66) $true
    Pr-Bisel $g 9 61 392 ($H - 68) $false
    # el escritorio verde azulado donde está abierta su ventana
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 128 128))), 404, 56, ($W - 408), 192)
    Pr-Bisel $g 404 56 ($W - 408) 192 $true
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 80 0 0 0))), 416, 65, 340, 186)
}
# lo que se mueve: el lienzo (sus dibujos, el paisaje o los hashes), el lápiz, su cara, la paleta y los datos
function Pr-Pintar($g, $W, $H, $k) {
    Pr-Reset; $e = $script:pr; $ahora = [Environment]::TickCount
    $ge = Pr-Geometria; if (-not $ge) { return }
    $lx = [float]$ge.CX; $ly = [float]$ge.CY; $lw = [float]$ge.CW; $lh = [float]$ge.CH; $es = $ge.S
    $mina = Pr-Mina-Activa
    $punta = $null; $goma = $null; $herr = 0; $col = 0; $estado = ''
    $g.SetClip((New-Object System.Drawing.RectangleF($lx, $ly, $lw, $lh)))
    if ($mina) {
        $herr = -1; $col = -1; $estado = '¡MINANDO CRIPTOMONEDA!'
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), $lx, $ly, $lw, $lh)
        $fh = FntP('Consolas', 7); $vh = New-Object System.Drawing.SolidBrush((C 0 255 0)); $i = 0
        foreach ($hx in $e.Hex) { $g.DrawString(($hx + $hx), $fh, $vh, ($lx + 3), ($ly + 3 + $i * ($lh / 9.4))); $i++ }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), ($lx + $lw * 0.30), ($ly + $lh * 0.42), ($lw * 0.40), ($lh * 0.14))
        $g.DrawString('MINANDO', (FntP('Consolas', 10, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 60 60))), ($lx + $lw * 0.34), ($ly + $lh * 0.43))
    } elseif ($e.Paisaje -gt 0) {
        $herr = @(2, 2, 5, 1, 1, 1, 4)[[Math]::Min(6, $e.Paisaje)]; $col = @(8, 8, 5, 6, 7, 9, 13)[[Math]::Min(6, $e.Paisaje)]
        $estado = if ($e.Listo -gt $ahora) { '¡Paisaje terminado!' } else { "Pintando el paisaje ($($e.Paisaje) de 6)" }
        $q = ($ahora - $e.ElemT) / 900.0
        if ($q -lt 1.0) {
            Pr-Dibujar-Paisaje $g ($e.Paisaje - 1) $lx $ly $lw $lh
            $g.SetClip((New-Object System.Drawing.RectangleF($lx, $ly, [float]($lw * $q), $lh)))
            Pr-Dibujar-Paisaje $g $e.Paisaje $lx $ly $lw $lh
            $punta = @{ X = $lx + $lw * $q; Y = $ly + $lh * (0.5 + 0.32 * [Math]::Sin($q * 14.0)) }
        } else { Pr-Dibujar-Paisaje $g $e.Paisaje $lx $ly $lw $lh }
    } else {
        foreach ($d in $e.Dib) {
            $res = Pr-Dibujar-Dibujo $g $d $lx $ly $lw $lh (($ahora - $d.T0) / [double]$PrTiempos.DibujoMs)
            if ($res) { $punta = $res; $col = $res.C; $estado = "Dibujando $($PrNombresDib[$d.N])..." }
        }
        if ($e.Borra -ne 0) {
            $q = [Math]::Min(1.0, ($ahora - $e.Borra) / 900.0); $herr = 3; $estado = 'Borrando el lienzo...'
            $g.FillRectangle([System.Drawing.Brushes]::White, $lx, $ly, [float]($lw * $q), $lh)
            $goma = @{ X = $lx + $lw * $q; Y = $ly + $lh * (0.5 + 0.35 * [Math]::Sin($q * 20.0)) }
        }
        if (-not $estado) { $estado = 'Para dibujar algo, espera un momento.' }
    }
    if ($e.Calor -ge 60.0 -and -not $mina) {
        $g.SetClip((New-Object System.Drawing.RectangleF($lx, $ly, $lw, $lh)))
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int][Math]::Min(55.0, ($e.Calor - 60.0) * 1.4)) 255 110 40))), $lx, $ly, $lw, $lh)
    }
    $g.ResetClip()
    if ($e.Listo -gt $ahora) { $g.DrawRectangle((New-Object System.Drawing.Pen((C 255 200 0), 2)), ($lx - 1), ($ly - 1), ($lw + 2), ($lh + 2)) }
    if ($punta) { Pr-Lapiz $g $punta.X $punta.Y ($es * 1.2) }
    elseif ($goma) { Pr-Goma $g $goma.X $goma.Y ($es * 1.3) }
    elseif (-not $mina) { Pr-Flecha $g ($lx + $lw * 0.88 + [Math]::Sin($ahora / 900.0) * 2) ($ly + $lh * 0.8 + [Math]::Cos($ahora / 1100.0) * 1.5) }
    if ($herr -ge 0) { Pr-Herramienta $g $ge.X $ge.Y $es $herr }
    # el color que usa: delante en el cuadro de colores y marcado en la paleta
    if ($col -ge 0) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((Pr-Color $col))), [float]($ge.X + 7.5 * $es), [float]($ge.Y + 162.5 * $es), [float](8 * $es), [float](7 * $es))
        $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 0 128), 1.4)), [float]($ge.X + (27.5 + $col * 8) * $es), [float]($ge.Y + 159.5 * $es), [float](9 * $es), [float](9 * $es))
    }
    # su cara: qué expresión pone
    $fx0 = $ge.X + 253 * $es; $fy0 = $ge.Y + 30 * $es; $fw0 = 81 * $es; $fh0 = 51 * $es
    $prog = 1.0; $dormido = ($ahora - $e.Ult) -gt 75000
    if ($mina) { $cara = 'mareo' }
    elseif ($ahora -lt $e.CaraHasta) { $cara = $e.Cara; $prog = ($ahora - $e.CaraT) / 180.0 }
    elseif ($e.Calor -ge 85.0) { $cara = 'susto' }
    elseif ($e.Calor -ge 70.0) { $cara = 'nervioso' }
    elseif ($e.Listo -gt $ahora) { $cara = 'orgulloso' }
    elseif ($punta) { $cara = 'concentrado' }
    elseif ($e.Borra -ne 0) { $cara = 'neutra' }
    elseif ($dormido) { $cara = 'dormido' }
    else { $cara = $e.Humor }
    # adónde mira: al lápiz si dibuja, a tu ratón si está encima del panel, y si no, a su aire
    $fcx = $fx0 + $fw0 / 2; $fcy = $fy0 + $fh0 / 2
    $obj = $null
    if ($punta) { $obj = @($punta.X, $punta.Y) } elseif ($goma) { $obj = @($goma.X, $goma.Y) }
    else { $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $rmx = $pt.X / $script:K; $rmy = $pt.Y / $script:K; if ($rmx -ge 0 -and $rmy -ge 0 -and $rmx -le $W -and $rmy -le $H) { $obj = @($rmx, $rmy) } }
    if ($obj) { $mira = @([Math]::Max(-1.0, [Math]::Min(1.0, ($obj[0] - $fcx) / 140.0)), [Math]::Max(-1.0, [Math]::Min(1.0, ($obj[1] - $fcy) / 80.0))) }
    else { $mira = @(([Math]::Sin($ahora / 1700.0) * 0.6), ([Math]::Sin($ahora / 2300.0) * 0.35)) }
    # habla mientras se escribe el bocadillo o suena su voz; parpadea de vez en cuando
    $hablando = (Pr-Voz-Suena) -or ($script:twTexto -and $script:twPos -lt ([string]$script:twTexto).Length)
    $habla = if ($hablando -and $cara -ne 'dormido') { 0.1 + 0.9 * [Math]::Abs([Math]::Sin($ahora / 85.0)) } else { 0.0 }
    $cierra = (($ahora % 3900) -lt 130) -or ((($ahora + 260) % 11700) -lt 130)
    Pr-Pintar-Cara $g $cara $fx0 ($fy0 + $(if (@('risa', 'contento', 'orgulloso') -contains $cara) { [Math]::Abs([Math]::Sin($ahora / 160.0)) * -1.5 } else { 0 })) $fw0 $fh0 $prog $mira $habla $cierra
    if (Pr-Voz-Suena) { $g.DrawString('♪', (FntP('Segoe UI Symbol', 8)), (New-Object System.Drawing.SolidBrush((C 220 130 0))), [float]($fx0 + $fw0 - 12), [float]($fy0 + 1 + [Math]::Sin($ahora / 150.0) * 1.5)) }
    # los datos, debajo de la cara (texto negro sobre gris, barras como las de antes)
    $hx0 = [float]($ge.X + 254 * $es); $hy0 = [float]($ge.Y + 89 * $es); $hw0 = [float](79 * $es)
    $fe = FntP('Tahoma', 5.8); $feb = FntP('Tahoma', 5.8, [System.Drawing.FontStyle]::Bold); $ng = [System.Drawing.Brushes]::Black
    $tmp = [int](38 + $e.Calor * 0.52); $cq = [Math]::Min(1.0, $e.Calor / 100.0)
    $g.DrawString('Overclock:', $fe, $ng, $hx0, $hy0)
    $g.DrawString("$tmp°C", $feb, (New-Object System.Drawing.SolidBrush($(if ($cq -ge 0.7) { (C 192 0 0) } else { (C 0 0 128) }))), [float]($hx0 + $hw0 - 22), $hy0)
    $g.FillRectangle([System.Drawing.Brushes]::White, $hx0, ($hy0 + 10), $hw0, 7); Pr-Bisel $g $hx0 ($hy0 + 10) $hw0 7 $true
    $bloques = [int][Math]::Round($cq * 10); $bw = ($hw0 - 3) / 10.0
    $cb = New-Object System.Drawing.SolidBrush($(if ($cq -ge 0.7) { (C 192 0 0) } else { (C 0 0 128) }))
    for ($i = 0; $i -lt $bloques; $i++) { $g.FillRectangle($cb, [float]($hx0 + 1.5 + $i * $bw), ($hy0 + 11.5), [float]($bw - 1), 4) }
    $cb.Dispose()
    $g.DrawString('Paisaje:', $fe, $ng, $hx0, ($hy0 + 19))
    $cw0 = ($hw0 - 5 * 2.0) / 6.0
    for ($i = 0; $i -lt $PrTiempos.Paisaje; $i++) {
        $on = ($i -lt $e.Paisaje) -or ($e.Listo -gt $ahora)
        $qx = [float]($hx0 + $i * ($cw0 + 2))
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($on) { (C 0 128 0) } else { (C 255 255 255) }))), $qx, ($hy0 + 29), [float]$cw0, 6); Pr-Bisel $g $qx ($hy0 + 29) $cw0 6 $true
    }
    $g.DrawString("Hechos: $($e.Terminados)", $fe, $ng, $hx0, ($hy0 + 37))
    if ($e.Calor -ge 70.0 -and -not $mina) { $g.DrawString('¡a punto de arder!', $feb, (New-Object System.Drawing.SolidBrush((C 192 0 0))), $hx0, ($hy0 + 47)) }
    else { $g.DrawString("Ánimo: $($PrNombresExpr[$cara])", $fe, (New-Object System.Drawing.SolidBrush((C 0 0 128))), $hx0, ($hy0 + 47)) }
    # la barra de estado: lo que hace y dónde está el lápiz
    $fsb = FntP('Tahoma', 5.5)
    $g.DrawString($estado, $fsb, $(if ($mina) { (New-Object System.Drawing.SolidBrush((C 192 0 0))) } else { $ng }), [float]($ge.X + 5 * $es), [float]($ge.Y + 177 * $es))
    if ($punta -or $goma) { $pp = if ($punta) { $punta } else { $goma }; $g.DrawString(("{0},{1}" -f [int](($pp.X - $lx) / $lw * 640), [int](($pp.Y - $ly) / $lh * 370)), $fsb, $ng, [float]($ge.X + 236 * $es), [float]($ge.Y + 177 * $es)) }
}

# --- Painter: la intro. Un ordenador del Blacksite arranca (lista de sistemas secuestrados) y, encima, se abre su
#     programa de dibujo: aparece su cara en la pantallita y el lápiz dibuja un sol y una flor; la ventana se aparta,
#     sale el título y guiña un ojo. Va por el reloj; la música del altavoz de Z-779 empieza con ella. Un clic la salta. ---
function Transicion-Pintor($final) {
    $script:prImg = Cargar-Img 'skins\painter\programa.png'
    $script:prT0 = 0; $script:prSaltarI = $false; $script:prBandera = @{}
    $ti = $PrIntro
    $script:prIDib = @(@{ N = 'sol'; SX = 0.06; SY = 0.12; Tam = 0.72; T0 = $ti.Cara + 300 }, @{ N = 'flor'; SX = 0.52; SY = 0.12; Tam = 0.72; T0 = $ti.Cara + 2300 })
    $script:iRecursos = @($script:prImg)
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $ti = $script:PrIntro
        $ms = if ($script:prT0 -gt 0) { [Environment]::TickCount - $script:prT0 } else { 0 }
        # 1) el arranque: lo que ha secuestrado
        $filas = @(
            @(500, 'URBANSHADE · HADAL DIVISION', 0), @(1100, 'NODO INTERNO Z-779 ............ OK', 0),
            @(1700, 'OVERCLOCK: ACTIVADO (NADIE LO HA PEDIDO)', 0), @(2300, 'MINANDO CRIPTOMONEDA ........ 100%', 1),
            @(2900, 'TORRETAS ............ SECUESTRADAS', 1), @(3400, 'ALTAVOCES .......... SECUESTRADOS', 1),
            @(3900, 'NAVEGACIÓN ......... SECUESTRADA', 1), @(4500, 'ABRIENDO the_p.AI.nter.exe ...', 2))
        $fb = FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold); $fi = 0
        foreach ($fl in $filas) {
            if ($ms -lt $fl[0]) { break }
            $nc = [int][Math]::Min([double]$fl[1].Length, ($ms - $fl[0]) * 0.06)
            $cl = if ($fl[2] -eq 1) { (C 255 130 150) } elseif ($fl[2] -eq 2) { (C 255 200 90) } else { (C 200 210 255) }
            $g.DrawString($fl[1].Substring(0, $nc), $fb, (New-Object System.Drawing.SolidBrush($cl)), 28, (30 + $fi * 22))
            $fi++
        }
        if ((([int]($ms / 380)) % 2) -eq 0 -and $ms -lt $ti.Abre) { $g.DrawString('█', $fb, (New-Object System.Drawing.SolidBrush((C 200 210 255))), 28, (30 + $fi * 22)) }
        $sl = New-Object System.Drawing.Pen((ARGB 26 255 255 255), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($sl, 0, $y, $W, $y) }; $sl.Dispose()
        if ($ms -ge $ti.Abre) {
            # el terminal se oscurece y pasa a la sala lila
            $qf = [Math]::Min(1.0, ($ms - $ti.Abre) / 1400.0)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](150 + 105 * $qf)) 0 110 110))), 0, 0, $W, $H)
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse(($W * 0.2), -30, ($W * 0.85), ($H + 70))
            $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pgb.CenterColor = (ARGB ([int](50 * $qf)) 200 255 255); $pgb.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 200 255 255))
            $g.FillPath($pgb, $gp); $pgb.Dispose(); $gp.Dispose()
            # 2) se abre su programa: crece desde el centro y luego se aparta a la derecha
            $img = $script:prImg
            if ($img) {
                $wc = $W * 0.68; $xc = ($W - $wc) / 2; $wd = $W * 0.56; $xd = $W - $wd - 18
                $qa = [Math]::Min(1.0, ($ms - $ti.Abre) / 320.0); $qa = 1 - [Math]::Pow(1 - $qa, 3)
                $qm = [Math]::Max(0.0, [Math]::Min(1.0, ($ms - $ti.Mueve) / 650.0)); $qm = 1 - [Math]::Pow(1 - $qm, 3)
                $vw = ($wc + ($wd - $wc) * $qm) * (0.55 + 0.45 * $qa); $vh = $vw * $img.Height / $img.Width
                $vx = ($xc + ($xd - $xc) * $qm) + (($wc + ($wd - $wc) * $qm) - $vw) / 2; $vy = ($H - $vh) / 2
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), [float]($vx + 6), [float]($vy + 7), [float]$vw, [float]$vh)
                $g.DrawImage($img, [float]$vx, [float]$vy, [float]$vw, [float]$vh)
                $ve = $vw / 340.0
                $cx = $vx + $vw * $script:PrCanvas[0]; $cy = $vy + $vh * $script:PrCanvas[2]; $cw = $vw * ($script:PrCanvas[1] - $script:PrCanvas[0]); $ch = $vh * ($script:PrCanvas[3] - $script:PrCanvas[2])
                if ($ms -ge $ti.Cara) {
                    # su cara aparece en la pantallita
                    $nom = if ($ms -ge $ti.Guino) { 'guino' } elseif ($ms -ge $ti.Cara + 2600) { 'contento' } else { 'sorpresa' }; $t0 = if ($ms -ge $ti.Guino) { $ti.Guino } elseif ($ms -ge $ti.Cara + 2600) { $ti.Cara + 2600 } else { $ti.Cara }
                    Pr-Pintar-Cara $g $nom ($vx + 253 * $ve) ($vy + 30 * $ve) (81 * $ve) (51 * $ve) (($ms - $t0) / 200.0) $null $(if ($ms -lt $ti.Cara + 2400) { [Math]::Abs([Math]::Sin($ms / 85.0)) } else { 0.0 })
                    # y el lápiz dibuja en el lienzo
                    $g.SetClip((New-Object System.Drawing.RectangleF([float]$cx, [float]$cy, [float]$cw, [float]$ch)))
                    $punta = $null
                    foreach ($d in $script:prIDib) { if ($ms -ge $d.T0) { $res = Pr-Dibujar-Dibujo $g $d $cx $cy $cw $ch (($ms - $d.T0) / 1800.0); if ($res) { $punta = $res } } }
                    $g.ResetClip()
                    if ($punta) { Pr-Lapiz $g $punta.X $punta.Y ($ve * 1.3) } else { Pr-Flecha $g ($cx + $cw * 0.88) ($cy + $ch * 0.8) }
                    Pr-Herramienta $g $vx $vy $ve 0
                }
            }
        }
        $ftit = FntP('Consolas', 26, [System.Drawing.FontStyle]::Bold)
        if ($ms -ge $ti.Titulo) { $tx = 'the_p.AI.nter'; $nc = [int][Math]::Min([double]$tx.Length, ($ms - $ti.Titulo) * 0.03); $s2 = $tx.Substring(0, $nc)
            $g.DrawString($s2, $ftit, (New-Object System.Drawing.SolidBrush((C 0 60 80))), 26, 94); $g.DrawString($s2, $ftit, [System.Drawing.Brushes]::White, 24, 92) }
        if ($ms -ge $ti.Sub) { $tx = 'Z-779  ·  Hadal Blacksite'; $nc = [int][Math]::Min([double]$tx.Length, ($ms - $ti.Sub) * 0.05); $g.DrawString($tx.Substring(0, $nc), (FntP('Consolas', 10)), (New-Object System.Drawing.SolidBrush((C 210 245 245))), 26, 134) }
        if ($ms -ge $ti.Frase) { $tx = '¡Vámonos, pequeño ordenador!'; $nc = [int][Math]::Min([double]$tx.Length, ($ms - $ti.Frase) * 0.035); $g.DrawString($tx.Substring(0, $nc), (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 214 120))), 26, 172) }
        # se funde a negro al final
        $resta = $ti.Fin - $ms; if ($resta -lt 700) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](255 * [Math]::Max(0.0, [Math]::Min(1.0, 1.0 - $resta / 700.0)))) 0 0 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $ti = $script:PrIntro
        if ($script:prT0 -eq 0) { $script:prT0 = [Environment]::TickCount; Pr-Musica-On; Sonido 'arranque' }
        $ms = [Environment]::TickCount - $script:prT0
        if ($ms -ge $ti.Abre -and -not $script:prBandera['abre']) { $script:prBandera['abre'] = $true; Sonido 'blip' }
        if ($ms -ge $ti.Cara -and -not $script:prBandera['cara']) { $script:prBandera['cara'] = $true; Pr-Reset; $script:pr.Saludado = (Pr-Voz 'intro') }
        foreach ($d in $script:prIDib) { $cl = 'd' + $d.N; if ($ms -ge $d.T0 -and -not $script:prBandera[$cl]) { $script:prBandera[$cl] = $true; Sonido 'garabato' } }
        if ($ms -ge $ti.Guino -and -not $script:prBandera['guino']) { $script:prBandera['guino'] = $true; Sonido 'blip' }
        if ($script:prSaltarI -or $ms -ge $ti.Fin) { if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 } }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    $script:iOv.Add_MouseDown({ $script:prSaltarI = $true })
    $script:iOv.Cursor = 'Hand'
}

# ---- sus voces del juego: skins\painter\voces.txt (una por línea: categoría|archivo|milisegundos|traducción) ----
# Suenan con su voz original y el bocadillo enseña la traducción. Mientras habla, la música baja.
$script:prVoces = $null; $script:prVozMp = $null; $script:prVozHasta = 0
function Pr-Voces {
    if ($script:prVoces) { return $script:prVoces }
    $script:prVoces = @{}
    $f = Ruta 'skins\painter\voces.txt'
    if (Test-Path $f) {
        foreach ($l in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) {
            if (-not $l.Trim() -or $l.StartsWith('#')) { continue }
            $pz = $l.Split([char]'|', 4); if ($pz.Count -lt 4) { continue }
            if (-not $script:prVoces.ContainsKey($pz[0])) { $script:prVoces[$pz[0]] = New-Object System.Collections.ArrayList }
            [void]$script:prVoces[$pz[0]].Add(@{ A = $pz[1]; Ms = [int]$pz[2]; T = $pz[3] })
        }
    }
    return $script:prVoces
}
function Pr-Voz-Suena { return ([Environment]::TickCount -lt $script:prVozHasta) }
function Pr-Voz-Off {
    if ($script:prVozMp) { try { $script:prVozMp.Stop(); $script:prVozMp.Close() } catch {}; $script:prVozMp = $null }
    $script:prVozHasta = 0
}
# dice una frase suya del juego; devuelve $false si no hay de ese tipo, no hay sonido o ya está hablando
function Pr-Voz($cat, $fijo) {
    if (-not $script:aj.Sonido -or (Pr-Voz-Suena)) { return $false }
    $v = Pr-Voces; if (-not $v.ContainsKey($cat)) { return $false }
    $x = Azar $v[$cat]
    try {
        Pr-Voz-Off
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta ('skins\painter\voces\' + $x.A))); $mp.Volume = [Math]::Min(1.0, (Pr-Volumen) * 1.3); $mp.Play()
        $script:prVozMp = $mp; $script:prVozHasta = [Environment]::TickCount + $x.Ms + 250
    } catch { return $false }
    if (-not $script:transicion) { if ($fijo) { Decir-Fijo $x.T } else { Decir $x.T } }
    return $true
}

# ================= VELVET (Gunsaw): LA GUARIDA, LA SEDA, EL HAMBRE Y EL ABRACITO =================
# SEDA (0-8): se recarga sola despacio. Escupir una telaraña sobre un botón gasta 2 (el botón queda atrapado y el
# primer clic la rompe: Velvet-Escupir y $script:telarana, como antes). HAMBRE (0-100): sube sola y con cada app
# (cada app es una especie de Gunsaw que se acerca a la telaraña). Al llegar a 100 envuelve al visitante en un CAPULLO
# que cuelga de la telaraña (se ven hasta 5) y el hambre vuelve a 0. Con mucha hambre le brillan los seis ojos.
# Clic en Velvet: sube la CONFIANZA (te pide un "abracito"); al llegar a 100 el abrazo es una TRAMPA: se abalanza,
# la telaraña lo cubre todo y... "era broma, cielo". Clic en un capullo: algo se mueve dentro.
$VvTiempos = @{ SedaMax = 8; SedaRegen = 0.005; Escupir = 2; HambreApp = 14; HambreSola = 0.008; Confianza = 18; Trampa = 80; TrampaFin = 34 }
# dónde cuelgan los capullos (x del hilo, y de la punta de abajo)
$VvCapullos = @(@(432, 128), @(470, 160), @(508, 118), @(452, 206), @(496, 196))
$script:vv = $null; $script:vvMusica = $null
function Vv-Reset {
    if (-not $script:vv) { $script:vv = @{ Seda = 6.0; Hambre = 30.0; Confianza = 0.0; Capullos = 0; Visitas = 0; TrampaT = 0; Mueve = -1; MueveT = 0; Fx = 0 } }
}
function Vv-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.6 * $script:aj.Volumen / 100.0)) }
function Vv-Musica-On {
    if (-not $script:aj.Sonido -or $script:vvMusica) { return }
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta 'skins\velvet\creeps.mp3')); $mp.Volume = (Vv-Volumen); $mp.Play()
        $script:vvMusica = $mp
    } catch { $script:vvMusica = $null }
}
function Vv-Musica-Off {
    if ($script:vvMusica) { try { $script:vvMusica.Stop(); $script:vvMusica.Close() } catch {}; $script:vvMusica = $null }
}
# escupe una telaraña sobre un botón si le queda seda (devuelve el nombre del botón o nada)
function Vv-Escupir {
    Vv-Reset; $e = $script:vv
    if ($e.Seda -lt $VvTiempos.Escupir -or $script:telarana) { return $null }
    $presa = Velvet-Escupir
    if ($presa) { $e.Seda -= $VvTiempos.Escupir; Sonido 'escupe' }
    return $presa
}
# una app abierta = un visitante de otra especie que se acerca a la telaraña
function Vv-App($linea) {
    Vv-Reset; $e = $script:vv; $k = $script:skin
    $esp = Azar $k.Especies; $e.Visitas++
    $e.Hambre = [Math]::Min(100.0, $e.Hambre + $VvTiempos.HambreApp)
    Flotante "+1 $esp" 420 236 (C 255 90 110) 13 'Consolas'
    if ($e.Hambre -ge 100.0) { Vv-Capullo $esp; return }
    if ($Rnd.Next(100) -lt 25) { $p = Vv-Escupir; if ($p) { Decir ((Azar $k.EscupeApp) -f $p); return } }
    Decir $linea
}
function Vv-Capullo($esp) {
    $e = $script:vv; $k = $script:skin
    $e.Capullos++; $e.Hambre = 0.0; $e.Fx = 14
    Sonido 'capullo'
    Decir-Fijo ((Azar $k.Capullo) -f $esp)
    $form.Invalidate()
}
function Vv-Clic {
    Vv-Reset; $e = $script:vv; $k = $script:skin
    if ($e.TrampaT -gt 0) { return }
    $e.Confianza = [Math]::Min(100.0, $e.Confianza + $VvTiempos.Confianza)
    if ($e.Confianza -ge 100.0) { Vv-Trampa; return }
    Sonido 'abrazo'
    foreach ($i in 0..1) { Flotante '♥' (580 + $Rnd.Next(0, 120)) (90 + $Rnd.Next(0, 80)) (C 230 40 70) 20 'Segoe UI Symbol' }
    if ($e.Confianza -ge 60.0) { Sonido 'latido'; Decir (Azar $k.Abrazo3) }
    elseif ($e.Confianza -ge 30.0) { Decir (Azar $k.Abrazo2) }
    else { Decir (Azar $k.Abrazo1) }
}
# el abracito era una trampa: se abalanza, la telaraña cubre la escena y todos los botones... y era broma (o no)
function Vv-Trampa {
    $e = $script:vv; $k = $script:skin
    $e.TrampaT = $VvTiempos.Trampa; $e.Confianza = 0.0
    Sonido 'lunge'
    if (-not $script:aj.Epilepsia) { Sacudir $form 10 }
    if ($script:grid) { foreach ($c in $script:grid.Controls) { $c.Invalidate() } }
    Decir-Fijo (Azar $k.Trampa) 'x' 500
}
# ¿hay un capullo bajo el ratón? (devuelve su número o -1)
function Vv-Capullo-En-Raton {
    if (-not $script:skin -or $script:skin.Estilo -ne 'arana' -or -not $script:vv -or (Ocupado)) { return -1 }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    $n = [Math]::Min(5, $script:vv.Capullos)
    for ($i = 0; $i -lt $n; $i++) { $c = $VvCapullos[$i]; if ($x -ge $c[0] - 12 -and $x -le $c[0] + 12 -and $y -ge $c[1] - 36 -and $y -le $c[1] + 2) { return $i } }
    return -1
}
function Vv-Tocar-Capullo($i) {
    $e = $script:vv; $e.Mueve = $i; $e.MueveT = 20
    Sonido 'siseo'; Decir (Azar $script:skin.CapulloClic)
}
function Vv-Tick {
    Vv-Reset; $e = $script:vv; $ahora = [Environment]::TickCount
    # la música: se repite al acabar, sigue el volumen y se calla si quitas el sonido
    if (-not $script:aj.Sonido) { Vv-Musica-Off }
    elseif (-not $script:vvMusica) { Vv-Musica-On }
    else {
        try {
            $mp = $script:vvMusica
            if ([Math]::Abs($mp.Volume - (Vv-Volumen)) -gt 0.01) { $mp.Volume = (Vv-Volumen) }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # la seda se recarga, el hambre sube sola y la confianza se olvida despacio
    if ($e.Seda -lt $VvTiempos.SedaMax) { $e.Seda = [Math]::Min([double]$VvTiempos.SedaMax, $e.Seda + $VvTiempos.SedaRegen) }
    if ($e.TrampaT -eq 0 -and $e.Hambre -lt 100.0) { $e.Hambre = [Math]::Min(99.9, $e.Hambre + $VvTiempos.HambreSola) }
    if ($e.Confianza -gt 0.0) { $e.Confianza = [Math]::Max(0.0, $e.Confianza - 0.03) }
    # la trampa: a mitad dice que era broma y al final suelta los botones
    if ($e.TrampaT -gt 0) {
        $e.TrampaT--
        if ($e.TrampaT -eq $VvTiempos.TrampaFin) { Decir-Fijo (Azar $script:skin.TrampaFin) 'x'; if ($script:grid) { foreach ($c in $script:grid.Controls) { $c.Invalidate() } } }
    }
    if ($e.MueveT -gt 0) { $e.MueveT--; if ($e.MueveT -eq 0) { $e.Mueve = -1 } }
    if ($e.Fx -gt 0) { $e.Fx-- }
    # se balancea despacio; en la trampa se abalanza hacia ti (hacia la izquierda) y vuelve
    $a = $script:actores['V']
    if ($a) {
        $q = $VvTiempos.Trampa - $e.TrampaT
        if ($e.TrampaT -gt 0 -and $q -lt 16) { $a.OX = - [Math]::Sin($q / 16.0 * [Math]::PI) * 90; $a.OY = - [Math]::Sin($q / 16.0 * [Math]::PI) * 14 }
        else { $a.OX = [Math]::Sin($ahora / 900.0) * 4; $a.OY = [Math]::Sin($ahora / 650.0) * 2.5 }
    }
    $Z = $script:K
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](410 * $Z), [int](50 * $Z))))
}
# una telaraña en abanico colgada de un punto (radios del ángulo a1 al a2, en grados; 90 = hacia abajo)
function Vv-Red($g, $cx, $cy, $radio, $col, $n, $a1, $a2, $anillos) {
    $pen = New-Object System.Drawing.Pen($col, 1.1)
    $pts = @()
    for ($i = 0; $i -lt $n; $i++) {
        $an = ($a1 + ($a2 - $a1) * $i / ($n - 1)) * [Math]::PI / 180
        $pts += , @([Math]::Cos($an), [Math]::Sin($an))
        $g.DrawLine($pen, [float]$cx, [float]$cy, [float]($cx + [Math]::Cos($an) * $radio), [float]($cy + [Math]::Sin($an) * $radio))
    }
    for ($r = 1; $r -le $anillos; $r++) {
        $f = $r / [double]($anillos + 0.4)
        for ($i = 0; $i -lt $n - 1; $i++) {
            $p1 = $pts[$i]; $p2 = $pts[$i + 1]; $cmb = $f * (0.92 + 0.08 * (($i + $r) % 2))
            $g.DrawLine($pen, [float]($cx + $p1[0] * $radio * $f), [float]($cy + $p1[1] * $radio * $f), [float]($cx + $p2[0] * $radio * $cmb), [float]($cy + $p2[1] * $radio * $cmb))
        }
    }
    $pen.Dispose()
}
# un capullo de seda colgando de un hilo (se menea si algo se mueve dentro)
function Vv-Dibujar-Capullo($g, $x, $y, $menea) {
    $ox = if ($menea -gt 0) { [Math]::Sin($menea * 1.3) * 4 } else { 0 }
    $g.DrawLine((New-Object System.Drawing.Pen((ARGB 150 230 225 235), 1)), [float]$x, 58, [float]($x + $ox), [float]($y - 34))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), [float]($x - 9 + $ox + 3), [float]($y - 34 + 3), 18, 36)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 222 214 220))), [float]($x - 9 + $ox), [float]($y - 34), 18, 36)
    $hilo = New-Object System.Drawing.Pen((ARGB 160 150 136 150), 1)
    for ($j = 0; $j -lt 5; $j++) { $yy = $y - 30 + $j * 6.5; $g.DrawBezier($hilo, [float]($x - 9 + $ox), [float]$yy, [float]($x - 3 + $ox), [float]($yy + 4), [float]($x + 3 + $ox), [float]($yy - 2), [float]($x + 9 + $ox), [float]($yy + 3)) }
    $hilo.Dispose()
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 120 100 116), 1)), [float]($x - 9 + $ox), [float]($y - 34), 18, 36)
}
# todo lo que se dibuja encima de la escena de Velvet: capullos, ojos que brillan, la trampa y la barra de abajo
function Vv-Pintar($g, $W, $H, $k) {
    $e = $script:vv
    # los capullos colgando de la telaraña
    $nc = if ($e) { [Math]::Min(5, $e.Capullos) } else { 0 }
    for ($i = 0; $i -lt $nc; $i++) { $c = $VvCapullos[$i]; Vv-Dibujar-Capullo $g $c[0] $c[1] $(if ($e.Mueve -eq $i) { $e.MueveT } else { 0 }) }
    if ($e -and $e.Capullos -gt 5) { $g.DrawString("+$($e.Capullos - 5)", (FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 222 214 220))), 520, 196) }
    # acaba de envolver a alguien: un destello rojo suave
    if ($e -and $e.Fx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($e.Fx * 6)) 180 10 30))), 404, 56, ($W - 404), ($H - 56)) }
    # la trampa: la escena se oscurece y una telaraña enorme lo cubre todo
    $tr = if ($e) { $e.TrampaT } else { 0 }
    if ($tr -gt 0) {
        $q = $VvTiempos.Trampa - $tr; $al = [Math]::Min(1.0, $q / 8.0) * [Math]::Min(1.0, $tr / 10.0)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](150 * $al)) 10 0 6))), 404, 56, ($W - 404), ($H - 56))
        Vv-Red $g 404 56 420 (ARGB ([int](200 * $al)) 240 235 240) 9 0 90 7
        Vv-Red $g $W 56 380 (ARGB ([int](170 * $al)) 240 235 240) 8 90 180 6
    }
    # los seis ojos brillan con el hambre (y en la trampa)
    $a = $script:actores['V']
    $int = if ($tr -gt 0) { 1.0 } elseif ($e) { [Math]::Max(0.0, ($e.Hambre - 55.0) / 45.0) } else { 0.0 }
    if ($a -and $int -gt 0.02) {
        $img = $a.Imgs[$a.Pose]; $r = $a.Rect
        $s = [Math]::Min($r[2] / $img.Width, $r[3] / $img.Height); $iw = $img.Width * $s; $ih = $img.Height * $s
        $ix = $r[0] + ($r[2] - $iw) / 2 + $a.OX; $iy = $r[1] + $r[3] - $ih + $a.OY
        $lat = if ($script:aj.Epilepsia) { 1.0 } else { 0.8 + 0.2 * [Math]::Sin([Environment]::TickCount / 260.0) }
        foreach ($o in $k.Ojos) {
            $ox = $ix + $o[0] * $iw; $oy = $iy + $o[1] * $ih; $rad = 14 * $o[2]
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($ox - $rad), [float]($oy - $rad), [float](2 * $rad), [float](2 * $rad))
            $brillo = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $brillo.CenterColor = (ARGB ([int](255 * [Math]::Min(1.0, $int * 1.3) * $lat)) 255 60 70); $brillo.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 255 0 30))
            $g.FillPath($brillo, $gp); $brillo.Dispose(); $gp.Dispose()
        }
    }
    # abajo: SEDA (8 hilos), HAMBRE y la CONFIANZA (el abracito)
    $osc = (ARGB 230 26 10 20); $cl = (C 236 228 232); $roj = (C 230 40 60)
    Yt-Pastilla $g 16 280 140 24 $osc $null $null 8
    $g.DrawString('SEDA', (FntP('Consolas', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 26, 285)
    $sd = if ($e) { [int][Math]::Floor($e.Seda) } else { 0 }
    for ($i = 0; $i -lt $VvTiempos.SedaMax; $i++) {
        $px = 62 + $i * 11
        $g.DrawLine((New-Object System.Drawing.Pen($(if ($i -lt $sd) { (C 236 228 232) } else { (C 70 50 62) }), 2)), [float]$px, 286, [float]($px + 4), 298)
        $g.DrawLine((New-Object System.Drawing.Pen($(if ($i -lt $sd) { (C 236 228 232) } else { (C 70 50 62) }), 2)), [float]($px + 4), 286, [float]$px, 298)
    }
    Yt-Pastilla $g 162 280 124 24 $osc $null $null 8
    $g.DrawString('HAMBRE', (FntP('Consolas', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 170, 285)
    $hv = if ($e) { $e.Hambre } else { 0 }
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 50 20 34))), (Ruta-Redonda 214 287 64 10 5))
    if ($hv -gt 1) { $g.FillPath((New-Object System.Drawing.SolidBrush($roj)), (Ruta-Redonda 214 287 ([Math]::Max(10.0, 64.0 * $hv / 100.0)) 10 5)) }
    Yt-Pastilla $g 292 280 106 24 $osc $null $null 8
    $g.DrawString('♥', (FntP('Segoe UI Symbol', 9, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($roj)), 300, 283)
    $cv = if ($e) { $e.Confianza } else { 0 }
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 50 20 34))), (Ruta-Redonda 322 287 68 10 5))
    if ($cv -gt 1) { $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 130 160))), (Ruta-Redonda 322 287 ([Math]::Max(10.0, 68.0 * $cv / 100.0)) 10 5)) }
}

# ================= ANGELA (Lobotomy Corporation): GESTIÓN DE LA INSTALACIÓN =================
# Cada app es un TRABAJO con una anomalía: tipo al azar (Instinto, Percepción, Apego, Represión) y resultado
# (Bueno 50 %: 4 PE-Boxes; Normal 35 %: 2; Malo 15 %: 0). La energía llena la CUOTA DEL DÍA; al completarla termina
# el día y empieza el siguiente (se guarda en ajustes.txt: AngelaDia). La cuota sube 4 cada día (de 20 a 60).
# FUSIÓN DE QLIPHOTH: cada trabajo suma 1 al medidor (uno malo, 2); con 4 sube el nivel (0-10) y la música pasa a la
# siguiente Neutral. En cada fusión puede escaparse una anomalía (BRECHA): sale en el monitor, suena First Warning y
# hay que hacer clic en el monitor hasta reprimirla. Si tarda, sube la emergencia: Second Warning a los 25 s y
# Third Warning a los 50 s (Angela abre los ojos). A los 90 s la reprime el Equipo Conejo (sin premio).
# Clic en Angela: frases; si la pinchas mucho se molesta y al final abre los ojos.
# A veces falla el FILTRO COGNITIVO y se ve un momento la instalación de verdad (no pasa en el modo seguro).
$AgTiempos = @{ Fusion = 4; Trompeta2 = 25000; Trompeta3 = 50000; Conejo = 90000; FinDia = 100; Filtro = 44 }
# canción según el nivel de Qliphoth (0..10) y según el nivel de emergencia (1..3)
$AgCanciones = @{
    Neutral = @('skins\angela\neutral1.mp3', 'skins\angela\neutral1.mp3', 'skins\angela\neutral1.mp3', 'skins\angela\neutral2.mp3', 'skins\angela\neutral2.mp3', 'skins\angela\neutral3.mp3', 'skins\angela\neutral3.mp3', 'skins\angela\neutral4.mp3', 'skins\angela\neutral4.mp3', 'skins\angela\neutral4.mp3', 'skins\angela\neutral4.mp3')
    Aviso = @('', 'skins\angela\aviso1.mp3', 'skins\angela\aviso2.mp3', 'skins\angela\aviso3.mp3')
}
# al hablar, cada cara alterna con la misma cara con la boca abierta
$AgBocas = @{ main = 'habla'; sonrie = 'habla'; risa = 'habla'; sorpresa = 'habla'; molesta = 'molesta_habla'; abiertos = 'abiertos_habla'; enfado = 'enfado_habla' }
# el monitor de la sala (x, y, ancho, alto): estado de la instalación o la anomalía escapada
$AgMonitor = @(414, 64, 170, 132)
$AgResultado = @{ bueno = 'Bueno'; normal = 'Normal'; malo = 'Malo' }
$script:ag = $null; $script:agMusica = $null; $script:agPista = ''; $script:agImgs = @{}
function Ag-Reset {
    if (-not $script:ag) {
        $script:ag = @{ PE = 0; Qli = 0; Nivel = 0; Trabajos = 0; Brecha = $null; Trompeta = 0; Completa = $false; FinT = 0
            Toques = 0.0; Cara = 'main'; CaraHasta = 0; Ultimo = $null; Golpe = 0; Rojo = 0; FiltroT = 0; Reprimidas = 0 }
    }
}
function Ag-Cuota { return [int][Math]::Min(60, 20 + 4 * ([int]$script:aj.AngelaDia - 1)) }
# imágenes de la skin (iconos, retratos, filtro) cargadas una sola vez
function Ag-Img($rel) {
    if (-not $rel) { return $null }
    if (-not $script:agImgs.ContainsKey($rel)) { $script:agImgs[$rel] = Cargar-Img $rel }
    return $script:agImgs[$rel]
}
function Ag-Liberar { foreach ($im in @($script:agImgs.Values)) { if ($im) { $im.Dispose() } }; $script:agImgs = @{} }
function Ag-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.55 * $script:aj.Volumen / 100.0)) }
# la canción que toca: la alarma si hay brecha; si no, la Neutral del nivel de Qliphoth (si ya suena, no la corta)
function Ag-Musica-On {
    if (-not $script:aj.Sonido -or -not $script:ag) { return }
    $e = $script:ag
    $pista = if ($e.Brecha -and $e.Trompeta -gt 0) { $AgCanciones.Aviso[[Math]::Min(3, $e.Trompeta)] } else { $AgCanciones.Neutral[[Math]::Min(10, [Math]::Max(0, $e.Nivel))] }
    if ($script:agMusica -and $script:agPista -eq $pista) { return }
    Ag-Musica-Off
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta $pista)); $mp.Volume = (Ag-Volumen); $mp.Play()
        $script:agMusica = $mp; $script:agPista = $pista
    } catch { $script:agMusica = $null; $script:agPista = '' }
}
function Ag-Musica-Off {
    if ($script:agMusica) { try { $script:agMusica.Stop(); $script:agMusica.Close() } catch {}; $script:agMusica = $null }
    $script:agPista = ''
}
# pone una cara durante un rato (0 = hasta la siguiente); la boca la mueve Ag-Tick
function Ag-Cara($c, $ms) {
    Ag-Reset; $script:ag.Cara = $c
    $script:ag.CaraHasta = if ($ms -gt 0) { [Environment]::TickCount + $ms } else { 0 }
    $a = $script:actores['A']
    if ($a -and $a.Imgs[$c]) { $a.Base = $c; if ($a.Hasta -eq 0) { $a.Pose = $c; $a.Frame = 0; Seleccionar-Frame $a; Invalidar-Escena } }
}
# la cara que pide Decir: 'serio' = molesta, 'ojos' = ojos abiertos, 'enfado', 'sonrie', 'risa', 'sorpresa'
function Ag-Cara-Decir($cara) {
    $c = switch ([string]$cara) { 'serio' { 'molesta' } 'ojos' { 'abiertos' } 'enfado' { 'enfado' } 'sonrie' { 'sonrie' } 'abiertos' { 'sonrie' } 'risa' { 'risa' } 'sorpresa' { 'sorpresa' } default { '' } }
    if ($c) { Ag-Cara $c 3500 }
}
# una app abierta = un trabajo con una anomalía
function Ag-App($linea) {
    Ag-Reset; $e = $script:ag; $k = $script:skin
    $tr = $k.Trabajos[$Rnd.Next($k.Trabajos.Count)]
    $r = $Rnd.Next(100)
    $res = if ($r -lt 50) { 'bueno' } elseif ($r -lt 85) { 'normal' } else { 'malo' }
    $pe = if ($res -eq 'bueno') { 4 } elseif ($res -eq 'normal') { 2 } else { 0 }
    $e.Trabajos++; $e.PE += $pe
    $e.Ultimo = @{ Tipo = $tr[0]; Nombre = $tr[1]; Res = $res; PE = $pe }
    Sonido 'trabajo'; if ($pe -gt 0) { Sonido 'pebox' }
    Flotante $(if ($pe -gt 0) { "+$pe PE" } else { '0 PE' }) 470 206 $(if ($pe -gt 0) { (C 255 190 70) } else { (C 230 80 70) }) 17 'Bahnschrift'
    $e.Qli += $(if ($res -eq 'malo') { 2 } else { 1 })
    $dicho = $false
    # primero la cuota: si se completa, la fusión de este trabajo ya no abre brechas
    if (-not $e.Completa -and $e.PE -ge (Ag-Cuota)) { Ag-Cuota-Completa; $dicho = $true }
    if ($e.Qli -ge $AgTiempos.Fusion) { $e.Qli = 0; if ($e.Completa) { $e.Nivel = [Math]::Min(10, $e.Nivel + 1) } else { Ag-Fusion; $dicho = $true } }
    if (-not $dicho) {
        if ($res -eq 'bueno') { Ag-Cara 'sonrie' 2600; Decir $linea }
        elseif ($res -eq 'normal') { Decir $linea }
        else { Ag-Cara 'molesta' 2600; Decir ((Azar $k.TrabajoMalo) -f $tr[1]) }
    }
    $form.Invalidate()
}
# el medidor de Qliphoth se llena: sube el nivel y a veces se escapa una anomalía
function Ag-Fusion {
    $e = $script:ag; $k = $script:skin
    $e.Nivel = [Math]::Min(10, $e.Nivel + 1)
    Sonido 'fusion'; Flotante "QLIPHOTH $($e.Nivel)" 426 100 (C 80 210 200) 16 'Bahnschrift'
    if (-not $e.Brecha -and -not $e.Completa -and $Rnd.Next(100) -lt (25 + $e.Nivel * 7)) { Ag-Brecha; return }
    Ag-Musica-On
    Ag-Cara 'molesta' 2500; Decir-Fijo ((Azar $k.Fusion) -f $e.Nivel) 'x' 1500
}
function Ag-Brecha {
    $e = $script:ag; $k = $script:skin
    $an = $k.Anomalias[$Rnd.Next($k.Anomalias.Count)]
    $e.Brecha = @{ A = $an; Vida = $an.Vida; T0 = [Environment]::TickCount }
    $e.Trompeta = 1; Sonido 'alarma'; Ag-Musica-On
    Ag-Cara 'sorpresa' 2500
    Decir-Fijo ((Azar $k.Brecha) -f $an.Nombre, $an.Riesgo) 'x'
    $form.Invalidate()
}
# clic en el monitor durante una brecha: un golpe a la anomalía
function Ag-Golpe {
    $e = $script:ag; if (-not $e -or -not $e.Brecha) { return }
    $e.Brecha.Vida--; $e.Golpe = 6; Sonido 'golpe'
    Flotante '-1' (480 + $Rnd.Next(0, 60)) (112 + $Rnd.Next(0, 30)) (C 255 90 70) 18 'Bahnschrift'
    if ($e.Brecha.Vida -le 0) { Ag-Reprimir $false }
    Invalidar-Escena
}
function Ag-Reprimir($conejo) {
    $e = $script:ag; $k = $script:skin; $n = $e.Brecha.A.Nombre
    $e.Brecha = $null; $e.Trompeta = 0; $e.Golpe = 0
    Sonido 'reprimida'; Ag-Musica-On
    if ($conejo) { Ag-Cara 'molesta' 3500; Decir-Fijo ((Azar $k.Conejo) -f $n) 'x' }
    else {
        $e.Reprimidas++; $e.PE += 3; Flotante '+3 PE' 470 206 (C 255 190 70) 17 'Bahnschrift'
        Ag-Cara 'sonrie' 3500; Decir-Fijo ((Azar $k.Reprimida) -f $n) 'x'
        if (-not $e.Completa -and $e.PE -ge (Ag-Cuota)) { Ag-Cuota-Completa }
    }
    $form.Invalidate()
}
function Ag-Cuota-Completa {
    $e = $script:ag; $e.Completa = $true; $e.FinT = $AgTiempos.FinDia
    Sonido 'fin'; Ag-Cara 'sonrie' 5000
    Decir-Fijo (Azar $script:skin.Cuota) 'x'
}
# empieza el día siguiente (se guarda en ajustes.txt)
function Ag-Nuevo-Dia {
    $e = $script:ag
    $script:aj.AngelaDia = [int]$script:aj.AngelaDia + 1; Guardar-Ajustes
    $e.PE = 0; $e.Qli = 0; $e.Nivel = 0; $e.Completa = $false; $e.Brecha = $null; $e.Trompeta = 0; $e.Ultimo = $null
    Ag-Musica-On; Ag-Cara 'main' 0
    Decir-Fijo ((Azar $script:skin.NuevoDia) -f $script:aj.AngelaDia) 'x'
}
function Ag-Clic {
    Ag-Reset; $e = $script:ag; $k = $script:skin
    if ($e.Brecha) { Ag-Cara 'molesta' 2000; Decir (Azar $k.ClicBrecha); return }
    $e.Toques += 1.0
    if ($e.Toques -ge 6.0) { $e.Toques = 3.0; $e.Rojo = 10; Ag-Cara 'enfado' 4000; Decir-Fijo (Azar $k.ClicEnfado) 'x' 1000 }
    elseif ($e.Toques -ge 3.0) { Ag-Cara 'molesta' 2600; Decir (Azar $k.ClicMolesta) }
    else { Ag-Cara (Azar @('sonrie', 'main', 'risa')) 2200; Decir (Azar $k.Clic) }
    $form.Invalidate()
}
# fallo del filtro cognitivo: durante 2 s se ve la instalación de verdad (nunca en el modo seguro)
function Ag-Filtro {
    if ($script:aj.Epilepsia) { return $false }
    Ag-Reset; $script:ag.FiltroT = $AgTiempos.Filtro; Sonido 'filtro'; Ag-Cara 'abiertos' 2600
    return $true
}
function Ag-Monitor-En-Raton {
    if (-not $script:skin -or $script:skin.Estilo -ne 'lobo' -or -not $script:ag -or -not $script:ag.Brecha -or (Ocupado)) { return $false }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    $m = $AgMonitor
    return ($x -ge $m[0] -and $x -le ($m[0] + $m[2]) -and $y -ge $m[1] -and $y -le ($m[1] + $m[3]))
}
function Ag-Tick {
    Ag-Reset; $e = $script:ag; $ahora = [Environment]::TickCount
    # la música: se repite al acabar, sigue el volumen y se calla si quitas el sonido
    if (-not $script:aj.Sonido) { Ag-Musica-Off }
    elseif (-not $script:agMusica) { Ag-Musica-On }
    else {
        try {
            $mp = $script:agMusica
            if ([Math]::Abs($mp.Volume - (Ag-Volumen)) -gt 0.01) { $mp.Volume = (Ag-Volumen) }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # la brecha: cuanto más tarda, más sube la emergencia; a los 90 s llega el Equipo Conejo
    if ($e.Brecha) {
        $dur = $ahora - $e.Brecha.T0
        if ($dur -gt $AgTiempos.Conejo) { Ag-Reprimir $true }
        else {
            $nueva = if ($dur -gt $AgTiempos.Trompeta3) { 3 } elseif ($dur -gt $AgTiempos.Trompeta2) { 2 } else { 1 }
            if ($nueva -gt $e.Trompeta) {
                $e.Trompeta = $nueva; Sonido 'alarma'; Ag-Musica-On
                $n = $e.Brecha.A.Nombre
                if ($nueva -eq 2) { Ag-Cara 'abiertos' 5000; Decir-Fijo ((Azar $script:skin.Trompeta2) -f $n) 'x' }
                else { Ag-Cara 'enfado' 6000; Decir-Fijo ((Azar $script:skin.Trompeta3) -f $n) 'x' }
            }
        }
    }
    # cuota completada: unos segundos después empieza el día siguiente
    if ($e.FinT -gt 0) { $e.FinT--; if ($e.FinT -eq 0) { Ag-Nuevo-Dia } }
    if ($e.FiltroT -gt 0) { $e.FiltroT--; if ($e.FiltroT -eq 0) { Decir (Azar $script:skin.Filtro) } }
    if ($e.Toques -gt 0.0) { $e.Toques = [Math]::Max(0.0, $e.Toques - 0.02) }
    if ($e.Golpe -gt 0) { $e.Golpe-- }
    if ($e.Rojo -gt 0) { $e.Rojo-- }
    # la cara vuelve a la de reposo (ojos abiertos si la emergencia es alta) y mueve la boca mientras escribe
    if ($e.CaraHasta -gt 0 -and $ahora -ge $e.CaraHasta) { $e.CaraHasta = 0; $e.Cara = $(if ($e.Trompeta -ge 2) { 'abiertos' } else { 'main' }) }
    $a = $script:actores['A']
    if ($a -and $a.Hasta -eq 0) {
        $hablando = $script:twPos -lt $script:twTexto.Length
        $pose = if ($hablando -and ([Math]::Floor($ahora / 140) % 2 -eq 1) -and $AgBocas[$e.Cara]) { $AgBocas[$e.Cara] } else { $e.Cara }
        $a.Base = $e.Cara
        if ($a.Pose -ne $pose -and $a.Imgs[$pose]) { $a.Pose = $pose; $a.Frame = 0; Seleccionar-Frame $a; Invalidar-Escena }
    }
    $Z = $script:K
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](410 * $Z), [int](50 * $Z))))
}
# dibuja una imagen cubriendo un recuadro con transparencia (para el filtro cognitivo)
function Ag-Cubrir-Alfa($g, $img, $x, $y, $w, $h, $alfa) {
    $s = [Math]::Max($w / $img.Width, $h / $img.Height); $sw = $w / $s; $sh = $h / $s
    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float][Math]::Max(0.0, [Math]::Min(1.0, $alfa))
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle([int]$x, [int]$y, [int]$w, [int]$h)), [float](($img.Width - $sw) * 0.6), [float](($img.Height - $sh) * 0.5), [float]$sw, [float]$sh, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $ia.Dispose()
}
# todo lo que se dibuja encima de la escena de Angela: filtro, alarma roja, monitor, fin del día y la barra de abajo
function Ag-Pintar($g, $W, $H, $k) {
    $e = $script:ag
    # filtro cognitivo: la instalación de verdad aparece y se va
    if ($e -and $e.FiltroT -gt 0) {
        $fi = Ag-Img $k.FiltroImg
        if ($fi) { $q = ($AgTiempos.Filtro - $e.FiltroT) / [double]$AgTiempos.Filtro; Ag-Cubrir-Alfa $g $fi 404 56 ($W - 404) ($H - 56) ([Math]::Sin($q * [Math]::PI) * 1.4) }
    }
    # emergencia de nivel 3: la sala se tiñe de rojo (en el modo seguro, sin latir)
    if ($e -and $e.Trompeta -ge 3) {
        $pul = if ($script:aj.Epilepsia) { 45 } else { 45 + [int](25 * [Math]::Sin([Environment]::TickCount / 500.0)) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $pul 200 0 0))), 404, 56, ($W - 404), ($H - 56))
    }
    if ($e -and $e.Rojo -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($e.Rojo * 8)) 200 0 0))), 404, 56, ($W - 404), ($H - 56)) }
    # el monitor de la sala
    $m = $AgMonitor; $mx = $m[0]; $my = $m[1]; $mw = $m[2]; $mh = $m[3]
    if ($e -and $e.Golpe -gt 0) { $mx += (($e.Golpe % 2) * 2 - 1) * 3 }
    $bre = [bool]($e -and $e.Brecha)
    $roj = (C 220 40 40); $amb = (C 255 170 40); $tur = (C 80 210 200); $bla = (C 230 236 242)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 130 0 0 0))), [float]($mx + 4), [float]($my + 4), [float]$mw, [float]$mh)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 235 8 11 15))), [float]$mx, [float]$my, [float]$mw, [float]$mh)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($bre) { $roj } else { $amb }))), [float]$mx, [float]$my, [float]$mw, 14)
    $f7 = FntP('Bahnschrift', 7, [System.Drawing.FontStyle]::Bold)
    $g.DrawString($(if ($bre) { 'BRECHA DE CONTENCIÓN' } else { 'CCTV  ·  SALA DE CONTROL' }), $f7, (New-Object System.Drawing.SolidBrush((C 12 14 18))), [float]($mx + 4), [float]($my + 1))
    if ($bre) {
        $b = $e.Brecha; $img = Ag-Img $b.A.Img
        if ($img) { $g.DrawImage($img, [float]($mx + 6), [float]($my + 20), 84, 84) }
        $sc = New-Object System.Drawing.Pen((ARGB 45 0 0 0), 1); for ($yy = $my + 20; $yy -lt $my + 104; $yy += 3) { $g.DrawLine($sc, [float]($mx + 6), [float]$yy, [float]($mx + 90), [float]$yy) }; $sc.Dispose()
        $g.DrawRectangle((New-Object System.Drawing.Pen($roj, 1)), [float]($mx + 6), [float]($my + 20), 84, 84)
        $g.DrawString($b.A.Nombre, (FntP('Bahnschrift', 8, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($bla)), (New-Object System.Drawing.RectangleF([float]($mx + 94), [float]($my + 18), 74, 30)))
        $g.DrawString("$($b.A.Codigo)  $($b.A.Riesgo)", $f7, (New-Object System.Drawing.SolidBrush($amb)), [float]($mx + 94), [float]($my + 50))
        for ($i = 0; $i -lt $b.Vida; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($roj)), [float]($mx + 95 + $i * 13), [float]($my + 68), 10, 10) }
        for ($i = 0; $i -lt $e.Trompeta; $i++) {
            $tx = $mx + $mw - 12 - $i * 11
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 12 14 18))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$tx, [float]($my + 2))), (New-Object System.Drawing.PointF([float]($tx + 5), [float]($my + 12))), (New-Object System.Drawing.PointF([float]($tx - 5), [float]($my + 12)))))
        }
        $g.DrawString('¡CLIC PARA REPRIMIR!', (FntP('Bahnschrift', 8, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($roj)), [float]($mx + 6), [float]($my + $mh - 22))
        $grosor = if ($script:aj.Epilepsia) { 2 } else { 2 + [Math]::Abs([Math]::Sin([Environment]::TickCount / 300.0)) * 2 }
        $g.DrawRectangle((New-Object System.Drawing.Pen($roj, [float]$grosor)), [float]$mx, [float]$my, [float]$mw, [float]$mh)
    } else {
        $dia = [int]$script:aj.AngelaDia
        $g.DrawString("DÍA $dia", (FntP('Bahnschrift', 14, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($bla)), [float]($mx + 6), [float]($my + 16))
        $g.DrawString('FUSIÓN DE QLIPHOTH', $f7, (New-Object System.Drawing.SolidBrush($tur)), [float]($mx + 7), [float]($my + 42))
        $nv = if ($e) { $e.Nivel } else { 0 }; $qv = if ($e) { $e.Qli } else { 0 }
        $g.DrawString("$nv", (FntP('Bahnschrift', 14, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($tur)), [float]($mx + $mw - 30), [float]($my + 34))
        for ($i = 0; $i -lt $AgTiempos.Fusion; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($i -lt $qv) { $tur } else { (C 30 44 50) }))), [float]($mx + 8 + $i * 22), [float]($my + 56), 18, 6) }
        $u = if ($e) { $e.Ultimo } else { $null }
        if ($u) {
            $it = Ag-Img "skins\angela\i_$($u.Tipo).png"; if ($it) { $g.DrawImage($it, [float]($mx + 8), [float]($my + 70), [float](28 * $it.Width / $it.Height), 28) }
            $ir = Ag-Img "skins\angela\i_$($u.Res).png"; if ($ir) { $g.DrawImage($ir, [float]($mx + 46), [float]($my + 70), 28, 28) }
            $g.DrawString($u.Nombre, $f7, (New-Object System.Drawing.SolidBrush($bla)), [float]($mx + 80), [float]($my + 72))
            $g.DrawString("$($AgResultado[$u.Res])  ·  +$($u.PE) PE", $f7, (New-Object System.Drawing.SolidBrush($amb)), [float]($mx + 80), [float]($my + 86))
        } else {
            $g.DrawString('Esperando órdenes, Manager.', $f7, (New-Object System.Drawing.SolidBrush((C 140 150 160))), [float]($mx + 8), [float]($my + 80))
        }
        $nr = if ($e) { $e.Reprimidas } else { 0 }
        $g.DrawString("Anomalías reprimidas: $nr", (FntP('Bahnschrift', 6.5)), (New-Object System.Drawing.SolidBrush((C 140 150 160))), [float]($mx + 7), [float]($my + $mh - 16))
        $g.DrawRectangle((New-Object System.Drawing.Pen($amb, 1.5)), [float]$mx, [float]$my, [float]$mw, [float]$mh)
    }
    # cuota completada: cartel de fin del día
    if ($e -and $e.Completa) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 215 6 8 11))), 404, 56, ($W - 404), 218)
        $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
        $g.DrawString('CUOTA DE ENERGÍA', (FntP('Bahnschrift', 12, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($amb)), (New-Object System.Drawing.RectangleF(404, 112, 200, 26)), $fmt)
        $g.DrawString('COMPLETADA', (FntP('Bahnschrift', 20, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($bla)), (New-Object System.Drawing.RectangleF(404, 132, 200, 36)), $fmt)
        $g.DrawString("DÍA $($script:aj.AngelaDia)  ▶  DÍA $([int]$script:aj.AngelaDia + 1)", (FntP('Segoe UI Symbol', 9, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($tur)), (New-Object System.Drawing.RectangleF(404, 174, 200, 20)), $fmt)
    }
    # abajo: el día, la energía de la cuota y el nivel de Qliphoth (o la alarma)
    $osc = (ARGB 230 16 22 30); $cl = (C 220 232 240)
    Yt-Pastilla $g 16 280 80 24 $osc "DÍA $($script:aj.AngelaDia)" $amb 8.5
    Yt-Pastilla $g 102 280 206 24 $osc $null $null 8
    $g.DrawString('ENERGÍA', (FntP('Bahnschrift', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 110, 285)
    $cuota = Ag-Cuota; $pe = if ($e) { [Math]::Min($e.PE, $cuota) } else { 0 }
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 40 32 14))), (Ruta-Redonda 160 287 90 10 5))
    if ($pe -gt 0) { $g.FillPath((New-Object System.Drawing.SolidBrush($amb)), (Ruta-Redonda 160 287 ([Math]::Max(10.0, 90.0 * $pe / $cuota)) 10 5)) }
    $g.DrawString("$pe/$cuota", (FntP('Bahnschrift', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($amb)), 256, 285)
    if ($e -and $e.Trompeta -gt 0) { Yt-Pastilla $g 314 280 84 24 (ARGB 235 150 20 20) "▲ ALERTA $($e.Trompeta)" (C 255 255 255) 8 }
    else { Yt-Pastilla $g 314 280 84 24 $osc "QLIPHOTH $(if ($e) { $e.Nivel } else { 0 })" $tur 7.5 }
}

# ================= MALKUTH (Library of Ruina): LIBROS DE HISTORIA, NIVEL DE EMOCIÓN Y RESPIRACIÓN =================
# Cada app que abres es un libro de historia para su planta: se apila en la mesa y, con 6, los coloca en la estantería.
# Cada 3 libros sube el NIVEL DE EMOCIÓN (de 0 a 5, como en las recepciones del juego) y la música pasa a la siguiente:
# Malkuth Story (0-1) → Battle 1 (2) → Battle 2 (3-4) → Battle 3 (5). Al llegar a 5: Realización de la Planta
# (la carta "The Will to Stand up Straight"). Si pasas un rato sin abrir nada, la emoción baja y vuelve la música tranquila.
# ÁNIMO: baja si una app no aparece, si la pinchas mucho o si abres apps demasiado deprisa (se acuerda de cuando
# exigía demasiado en el Equipo de Control). Por debajo de 30 se hunde (cara sombría). Haz clic en ella y hacéis
# juntos su ejercicio de respiración ("uno, coge aire... y dos, suéltalo"). Al acabar vuelve a estar animada.
# Clic normal: frases; a veces se tropieza (su sprite de combate esquivando). Lo que lleva hecho se guarda al cambiar de skin.
$MkTiempos = @{ LibrosNivel = 3; Estante = 6; Bajar = 75000; Prisa = 5; PrisaMs = 10000; Respira = 6800; Hundirse = 30 }
# canción según el nivel de emoción (0..5)
$MkCanciones = @('skins\malkuth\historia.mp3', 'skins\malkuth\historia.mp3', 'skins\malkuth\batalla1.mp3', 'skins\malkuth\batalla2.mp3', 'skins\malkuth\batalla2.mp3', 'skins\malkuth\batalla3.mp3')
# colores de los lomos de los libros de la mesa
$MkLomos = @((C 196 150 60), (C 150 60 40), (C 70 96 60), (C 60 70 120), (C 120 80 40), (C 220 196 140))
$script:mk = $null; $script:mkMusica = $null; $script:mkPista = ''; $script:mkEgo = $null
function Mk-Reset {
    if (-not $script:mk) {
        $script:mk = @{ Libros = 0; Mesa = 0; Estantes = 0; Nivel = 0; Puntos = 0; Animo = 80.0; Toques = 0.0; Ultima = [Environment]::TickCount
            Apps = (New-Object System.Collections.ArrayList); Hundida = $false; Respira = 0; RespiraT0 = 0; RespiraDos = $false; Fx = 0; EgoT = 0 }
    }
}
function Mk-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.6 * $script:aj.Volumen / 100.0)) }
# pone la canción del nivel de emoción actual (si ya está sonando, no la corta)
function Mk-Musica-On {
    if (-not $script:aj.Sonido -or -not $script:mk) { return }
    $pista = $MkCanciones[[Math]::Min(5, [Math]::Max(0, $script:mk.Nivel))]
    if ($script:mkMusica -and $script:mkPista -eq $pista) { return }
    Mk-Musica-Off
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta $pista)); $mp.Volume = (Mk-Volumen); $mp.Play()
        $script:mkMusica = $mp; $script:mkPista = $pista
    } catch { $script:mkMusica = $null; $script:mkPista = '' }
}
function Mk-Musica-Off {
    if ($script:mkMusica) { try { $script:mkMusica.Stop(); $script:mkMusica.Close() } catch {}; $script:mkMusica = $null }
    $script:mkPista = ''
}
# cara de reposo: la sombría si está hundida, la normal si no
function Mk-Base {
    $a = $script:actores['M']; if (-not $a -or -not $script:mk) { return }
    $nueva = if ($script:mk.Hundida) { 'sombria' } else { 'main' }
    if ($a.Base -ne $nueva) { $a.Base = $nueva; if ($a.Hasta -eq 0) { Actor-Pose 'M' $nueva 0 } }
}
function Mk-Cara($pose, $ms) {
    if ($script:mk -and $script:mk.Respira -gt 0) { return }   # mientras respira no cambia de cara
    Actor-Pose 'M' $pose $ms
}
# sube o baja el ánimo; si baja de 30 se hunde (devuelve $true si se acaba de hundir)
function Mk-Animo($d) {
    Mk-Reset; $e = $script:mk
    $e.Animo = [Math]::Max(0.0, [Math]::Min(100.0, $e.Animo + $d))
    if (-not $e.Hundida -and $e.Animo -lt $MkTiempos.Hundirse) {
        $e.Hundida = $true; $null = Mk-Base; $null = Actor-Pose 'M' 'sombria' 0
        $null = Decir-Fijo (Azar $script:skin.Hundida) 'x'
        return $true
    }
    return $false
}
# una app abierta = un libro de historia para la planta
function Mk-App($linea) {
    Mk-Reset; $e = $script:mk; $k = $script:skin; $ahora = [Environment]::TickCount
    $e.Ultima = $ahora
    # ¿demasiado deprisa? se acuerda de cuando exigía demasiado a su equipo
    [void]$e.Apps.Add($ahora)
    while ($e.Apps.Count -gt 0 -and ($ahora - $e.Apps[0]) -gt $MkTiempos.PrisaMs) { $e.Apps.RemoveAt(0) }
    $e.Libros++; $e.Mesa++; $e.Puntos++
    Sonido 'pagina'
    Flotante '+1 libro' 466 196 (C 250 232 180) 15 'Palatino Linotype'
    $dicho = $false
    if ($e.Apps.Count -ge $MkTiempos.Prisa) {
        $e.Apps.Clear()
        if (-not (Mk-Animo -12)) { Mk-Cara 'enfado' 2600; Decir-Fijo (Azar $k.Prisa) 'x' }
        $dicho = $true
    } else { [void](Mk-Animo 3) }
    # la mesa se llena: los coloca en la estantería
    if ($e.Mesa -ge $MkTiempos.Estante) {
        $e.Mesa = 0; $e.Estantes++; Sonido 'libro'
        if (-not $dicho -and -not $e.Hundida) { Mk-Cara 'feliz' 3000; Decir (Azar $k.Estante); $dicho = $true }
    }
    # nivel de emoción: cada 3 libros sube uno y cambia la música
    if ($e.Puntos -ge $MkTiempos.LibrosNivel -and $e.Nivel -lt 5) {
        $e.Puntos = 0; $e.Nivel++; $e.Fx = 12
        Sonido 'emocion'; Mk-Musica-On
        Flotante "EMOCIÓN $($e.Nivel)" 584 110 (C 255 214 110) 18 'Palatino Linotype'
        if ($e.Nivel -ge 5) { Mk-Realizacion; $dicho = $true }
        elseif (-not $dicho -and -not $e.Hundida) { Mk-Cara 'decidida' 3000; Decir-Fijo (Azar $k.Emocion) 'x' 1500; $dicho = $true }
    }
    if ($e.Nivel -ge 5) { $e.Puntos = 0 }
    if (-not $dicho) {
        if ($e.Hundida) { Decir (Azar $k.HundidaApp) }
        else { Mk-Cara (Azar @('feliz', 'decidida')) 2400; Decir $linea }
    }
    $form.Invalidate()
}
# nivel de emoción 5: Realización de la Planta de Historia
function Mk-Realizacion {
    $e = $script:mk; $e.EgoT = 90; $e.Animo = 100.0
    if ($e.Hundida) { $e.Hundida = $false; Mk-Base }
    Sonido 'ego'; Actor-Pose 'M' 'combate' 4200
    Decir-Fijo (Azar $script:skin.Realizacion) 'x'
}
# una app que no aparece: le sienta fatal
function Mk-Fallo($txt) {
    Mk-Reset
    if (Mk-Animo -22) { return }
    Mk-Cara 'herida' 1600; Decir $txt
}
function Mk-Clic {
    Mk-Reset; $e = $script:mk; $k = $script:skin
    if ($e.Respira -gt 0) { Decir-Fijo (Azar @('Shhh... respira conmigo. Despacio.', '*Te hace un gesto con la mano: despacio.* Aún no hemos terminado.')) 'x' 0; return }
    if ($e.Hundida) {
        # el ejercicio de respiración (el que le enseñó Roland)
        $ahora = [Environment]::TickCount
        $e.Respira = $ahora + $MkTiempos.Respira; $e.RespiraT0 = $ahora; $e.RespiraDos = $false
        Actor-Pose 'M' 'respira' ($MkTiempos.Respira + 200)
        Sonido 'respira'
        Decir-Fijo 'Vale... vamos a respirar hondo. Uno, coge aiiire...' 'x' 0
        $form.Invalidate(); return
    }
    $e.Toques += 1.0
    if ($e.Toques -ge 5.0) {
        $e.Toques = 2.0
        if (-not (Mk-Animo -15)) { Mk-Cara 'enfado' 2200; Decir (Azar $k.Pesado) }
    } elseif ($Rnd.Next(100) -lt 22) {
        Actor-Pose 'M' 'tropiezo' 1500; Sonido 'tropiezo'
        $a = $script:actores['M']; if ($a) { $a.Salto = 12 }
        Decir (Azar $k.Tropiezo)
    } else {
        Mk-Cara (Azar @('feliz', 'decidida', 'main')) 2200; Decir (Azar $k.Clic)
    }
    $form.Invalidate()
}
function Mk-Tick {
    Mk-Reset; $e = $script:mk; $ahora = [Environment]::TickCount
    # la música: se repite al acabar, sigue el volumen y se calla si quitas el sonido
    if (-not $script:aj.Sonido) { Mk-Musica-Off }
    elseif (-not $script:mkMusica) { Mk-Musica-On }
    else {
        try {
            $mp = $script:mkMusica
            if ([Math]::Abs($mp.Volume - (Mk-Volumen)) -gt 0.01) { $mp.Volume = (Mk-Volumen) }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # si no abres nada en un rato, la emoción baja un nivel (y la música se calma)
    if ($e.Nivel -gt 0 -and ($ahora - $e.Ultima) -gt $MkTiempos.Bajar) { $e.Nivel--; $e.Puntos = 0; $e.Ultima = $ahora; Mk-Musica-On }
    # los toques se olvidan solos; el ánimo se recupera despacio (si está hundida no: eso solo lo arregla respirar)
    if ($e.Toques -gt 0.0) { $e.Toques = [Math]::Max(0.0, $e.Toques - 0.015) }
    if (-not $e.Hundida -and $e.Animo -lt 70.0) { $e.Animo = [Math]::Min(70.0, $e.Animo + 0.01) }
    # el ejercicio de respiración: a la mitad suelta el aire; al acabar, vuelve a estar bien
    if ($e.Respira -gt 0) {
        if (-not $e.RespiraDos -and ($ahora - $e.RespiraT0) -ge $MkTiempos.Respira / 2) { $e.RespiraDos = $true; Sonido 'respira'; Decir-Fijo 'Y dos... suéltalo. Fuuuu...' 'x' 0 }
        if ($ahora -ge $e.Respira) {
            $e.Respira = 0; $e.Hundida = $false; $e.Animo = 80.0; $e.Toques = 0.0
            Mk-Base; Actor-Pose 'M' 'feliz' 3500
            Decir-Fijo (Azar $script:skin.Recupera) 'x'
        }
    }
    if ($e.Fx -gt 0) { $e.Fx-- }
    if ($e.EgoT -gt 0) { $e.EgoT--; if ($e.EgoT -eq 0 -and $script:mkEgo) { $script:mkEgo.Dispose(); $script:mkEgo = $null } }
    # la vela, el círculo de respirar y la carta se mueven: se repinta la escena y la barra de abajo
    $Z = $script:K
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](410 * $Z), [int](50 * $Z))))
}
# la mesa: libros apilados y una vela con forma de patata (le encantan las dos cosas)
function Mk-Pintar-Mesa($g, $e) {
    $n = if ($e) { $e.Mesa } else { 0 }
    for ($i = 0; $i -lt $n; $i++) {
        $bw = 50 + (($i * 7) % 12); $bx = 452 + (($i * 5) % 9) - 4; $by = 242 - $i * 9
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($MkLomos[$i % $MkLomos.Count])), [float]$bx, [float]$by, [float]$bw, 9)
        $g.DrawRectangle((New-Object System.Drawing.Pen((C 40 24 10), 1)), [float]$bx, [float]$by, [float]$bw, 9)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 250 230 170))), [float]($bx + 6), [float]($by + 3), [float]($bw - 12), 2)
    }
    # vela-patata: cuerpo marrón con "ojos" de patata, mecha y una llama que se mueve suave (sin parpadeos)
    $vx = 556; $vy = 226
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 196 150 90))), $vx, $vy, 30, 26)
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 110 76 40), 1.5)), $vx, $vy, 30, 26)
    foreach ($q in @(@(8, 9), @(19, 14), @(12, 18))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 140 100 56))), [float]($vx + $q[0]), [float]($vy + $q[1]), 3, 2) }
    $g.DrawLine((New-Object System.Drawing.Pen((C 40 30 20), 1.5)), [float]($vx + 15), [float]$vy, [float]($vx + 15), [float]($vy - 5))
    $tl = [Environment]::TickCount / 1000.0; $os = [Math]::Sin($tl * 5.3) * 1.5; $al = 14 + [Math]::Sin($tl * 3.1) * 2
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 60 255 200 90))), [float]($vx + 3), [float]($vy - 22), 24, 24)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 196 80))), [float]($vx + 11 + $os), [float]($vy - 5 - $al), 8, [float]$al)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 246 200))), [float]($vx + 13 + $os), [float]($vy - 1 - $al * 0.6), 4, [float]($al * 0.5))
}

# ================= ANIMACIÓN DE FONDO (planta rodadora, agua de Dune) =================
$script:fase = 0.0; $script:tumbX = -300; $script:salto = 0
$ambTimer = New-Object System.Windows.Forms.Timer
$ambTimer.Interval = 50
# MODO SEGURO (epilepsia): apaga todos los destellos, flashes y parpadeos de color de las skins.
# Si añades un efecto nuevo que parpadee o haga flash, pon aquí su variable a 0.
function Sin-Destellos {
    if (-not $script:aj.Epilepsia) { return }
    $script:fogonazo = 0; $script:kyFlash = 0; $script:destello = 0; $script:rojoFx = 0; $script:flash = 0
    $script:enfadoFx = 0; $script:popFx = 0; $script:tkFx = 0; $script:pzFx = 0; $script:invFx = 0; $script:invEst = 0
    if ($script:gr) { $script:gr.Fx = 0 }
    if ($script:nn) { $script:nn.Fx = 0 }
    if ($script:mk) { $script:mk.Fx = 0 }
    if ($script:ag) { $script:ag.Rojo = 0; $script:ag.Golpe = 0; $script:ag.FiltroT = 0 }
    if ($script:vv) { $script:vv.Fx = 0 }
    if ($script:wg) { $script:wg.Rayo = 0; $script:wg.Fx = 0 }
    if ($script:es) { $script:es.Fx = 0 }
    if ($script:kn) { $script:kn.Fx = 0 }
    if ($script:el) { $script:el.Fx = 0 }
    foreach ($a in @($script:actores.Values)) { $a.Flash = 0; $a.Temblor = 0 }
}
$ambTimer.Add_Tick({
    Sin-Destellos
    $k = $script:skin; $Z = $script:K
    if ((Ocupado) -or -not $k) { return }
    $script:fase += 0.14
    if ($k.Estilo -eq 'oeste') {
        # planta rodadora cruzando la escena, buitres, polvo, agujeros de bala que se borran, fogonazo y duelo
        $script:tumbX += 5
        if ($script:tumbX -gt 800) { $script:tumbX = 380 - $Rnd.Next(0, 700) }
        $hay = $true
        if ($script:duelo) { Zodiac-Duelo-Tick }
        for ($i = $script:agujeros2.Count - 1; $i -ge 0; $i--) { $script:agujeros2[$i].T--; if ($script:agujeros2[$i].T -le 0) { $script:agujeros2.RemoveAt($i); $hay = $true } }
        if ($script:fogonazo -gt 0) { $script:fogonazo--; $hay = $true }
        if ($hay) { Invalidar-Escena; $form.Invalidate((New-Object System.Drawing.Rectangle([int](400 * $Z), [int](200 * $Z), [int](($form.ClientSize.Width / $Z - 400) * $Z), [int](60 * $Z)))) }
    }
    if ($k.Agua -and $script:pb) {
        # Dune flota en el agua; da un saltito cuando come
        $extra = 0; if ($script:salto -gt 0) { $script:salto--; $extra = - [Math]::Sin($script:salto / 10.0 * [Math]::PI) * 12 }
        $script:pb.Top = [int](($k.Pb[1] + [Math]::Sin($script:fase) * 3 + $extra) * $Z)
        $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](296 * $Z), $form.ClientSize.Width, [int](20 * $Z))))
    }
    if ($k.Estilo -eq 'culto' -and $script:ritualFx -gt 0) {
        $script:ritualFx--
        if ($script:ritualFx -eq 30) { Sonido 'tentaculos' }
        $form.Invalidate()
    }
    if ($k.Estilo -eq 'kaiju') { Kaiju-Particulas }
    if ($k.Estilo -in @('dod', 'pressure')) { Efectos-Caza }
    if ($k.Estilo -eq 'teto') { Teto-Tick }
    if ($k.Estilo -eq 'enfosi') { Enfosi-Tick }
    if ($k.Estilo -eq 'femta') { Token-Tick }
    if ($k.Estilo -eq 'pop') { Tetra-Tick }
    if ($k.Estilo -eq 'pizza') { Kevin-Tick }
    if ($k.Estilo -eq 'punk') { Ky-Tick }
    if ($k.Estilo -eq 'gran') { Gran-Tick }
    if ($k.Estilo -eq 'abismo') { Nn-Tick }
    if ($k.Estilo -eq 'historia') { Mk-Tick }
    if ($k.Estilo -eq 'lobo') { Ag-Tick }
    if ($k.Estilo -eq 'arana') { Vv-Tick }
    if ($k.Estilo -eq 'clima') { Wg-Tick }
    if ($k.Estilo -eq 'pintor') { Pr-Tick }
    if ($k.Estilo -eq 'evil') { Es-Tick }
    if ($k.Estilo -eq 'niebla') { Sf-Tick }
    if ($k.Estilo -eq 'knight') { Kn-Tick }
    if ($k.Estilo -eq 'corrupta') { El-Tick }
    if ($k.Estilo -eq 'boneyard') { Dy-Tick }
})

# ================= EVIL SCARY (Die of Death): LA RONDA ESPECIAL =================
# Como en el juego: se acerca a saltitos ("rebotes"); cada 6 rebotes suena la alarma STALL, STALL y después
# hace una carga de 8 saltos rápidos. Si llega hasta ti (distancia 0) te da un susto y vuelve al horizonte.
# Clic en él: PUNCH (lo aleja un poco). Clic durante la alarma o la carga: BLOCK (logro "Lucid Nightmare").
# Cada app que abres hace ruido y le hace botar hacia ti.
# Tiempos en milisegundos (cámbialos aquí para que sea más o menos agresivo):
$EsTiempos = @{ Rebote = 6000; Aviso = 2600; CargaIni = 430; CargaMin = 170; Susto = 1600 }
$script:es = $null
function Es-Reset {
    if (-not $script:es) {
        # a veces sale gigante (como en el juego): bota menos veces pero más lejos
        $gig = ($Rnd.Next(10) -eq 0)
        $script:es = @{ Dist = 100.0; Vis = 100.0; Rebotes = 0; Fase = 'lento'; Prox = [Environment]::TickCount + $EsTiempos.Rebote
            Cuenta = 0; Paso = $EsTiempos.CargaIni; Sustos = 0; Bloqueos = 0; Fx = 0; Hop = 0; Gigante = $gig }
    }
}
function Es-Sonido-Rebote {
    $d = $script:es.Dist
    Sonido $(if ($d -gt 60) { 'lejos' } elseif ($d -gt 30) { 'medio' } else { 'cerca' })
}
function Es-Rebote($n) {
    Es-Reset; $e = $script:es
    if ($e.Gigante) { $n = $n * 1.6 }
    $e.Dist = [Math]::Max(0.0, $e.Dist - $n); $e.Hop = 8
    Es-Sonido-Rebote
    if ($e.Dist -le 0.0) { Es-Susto }
}
function Es-Susto {
    $e = $script:es; $k = $script:skin
    $e.Sustos++; $e.Fx = [int]($EsTiempos.Susto / 50); $e.Fase = 'lento'; $e.Rebotes = 0
    $e.Prox = [Environment]::TickCount + $EsTiempos.Rebote + $EsTiempos.Susto
    Sonido 'grito'; Sacudir $form 14
    Decir-Fijo (Azar $k.Atrapado)
    $e.Dist = 100.0
}
function Es-App($linea) { Es-Reset; Es-Rebote 4.0; Decir $linea }
function Es-Clic {
    Es-Reset; $e = $script:es; $k = $script:skin
    if ($e.Fase -in @('aviso', 'carga')) {
        # BLOCK: justo cuando va a cargar o está cargando
        $e.Bloqueos++; $e.Dist = 100.0; $e.Fase = 'lento'; $e.Rebotes = 0; $e.Prox = [Environment]::TickCount + $EsTiempos.Rebote
        Sonido 'violin'
        Flotante 'LUCID NIGHTMARE' 450 120 (C 255 220 90) 20 'Arial Black'
        Decir-Fijo (Azar $k.Bloqueo)
    } else {
        # PUNCH: lo aleja un poco (no le hace daño: nadie puede)
        $e.Dist = [Math]::Min(100.0, $e.Dist + 12.0); $e.Hop = 6
        Flotante 'PUNCH!' (560 + $Rnd.Next(-40, 40)) 130 (C 255 255 255) 18 'Arial Black'
        Decir (Azar $k.Clic)
    }
    $form.Invalidate()
}
function Es-Tick {
    Es-Reset; $e = $script:es; $k = $script:skin; $ahora = [Environment]::TickCount
    if ($e.Fx -gt 0) { $e.Fx-- }
    if ($e.Hop -gt 0) { $e.Hop-- }
    if (-not (Ocupado) -and $ahora -ge $e.Prox) {
        switch ($e.Fase) {
            'lento' {
                $e.Rebotes++; $sustosAntes = $e.Sustos; Es-Rebote 5.0
                # si este rebote le ha hecho llegar hasta ti, ya se ha reiniciado: no toca alarma
                if ($e.Sustos -eq $sustosAntes) {
                    if ($e.Rebotes % $(if ($e.Gigante) { 4 } else { 6 }) -eq 0) {
                        # la alarma del Airbus: se queda quieto y avisa
                        $e.Fase = 'aviso'; $e.Prox = $ahora + $EsTiempos.Aviso; Sonido 'stall'; Decir-Fijo (Azar $k.Stall)
                    } else { $e.Prox = $ahora + $EsTiempos.Rebote }
                }
            }
            'aviso' { $e.Fase = 'carga'; $e.Cuenta = $(if ($e.Gigante) { 4 } else { 8 }); $e.Paso = $EsTiempos.CargaIni; $e.Prox = $ahora; Sonido 'violin' }
            'carga' {
                Es-Rebote 7.0
                if ($e.Fase -eq 'carga') {
                    $e.Cuenta--; $e.Paso = [Math]::Max($EsTiempos.CargaMin, $e.Paso - 35)
                    if ($e.Cuenta -le 0) { $e.Fase = 'lento'; $e.Prox = $ahora + $EsTiempos.Rebote } else { $e.Prox = $ahora + $e.Paso }
                }
            }
        }
    }
    # se mueve suave hasta su distancia y crece al acercarse (del horizonte hasta tus narices)
    $e.Vis += ($e.Dist - $e.Vis) * 0.35
    $a = $script:actores['E']
    if ($a) {
        $c = 1.0 - $e.Vis / 100.0
        $w = (90 + 270 * $c) * $(if ($e.Gigante) { 1.35 } else { 1.0 }); $h = $w * 114.0 / 300.0
        $suelo = 176 + 104 * $c - [Math]::Sin(($e.Hop / 8.0) * [Math]::PI) * 14
        $cx = 590 + [Math]::Sin($ahora / 1700.0) * 30 * (1 - $c)
        $a.Rect = @([int]($cx - $w / 2), [int]($suelo - $h), [int]$w, [int]$h)
    }
    $form.Invalidate()
}

# ================= SOFT FUZZY MAN (Lemon Demon · Aimkid): NECESITA SENTIR QUE EXISTE =================
# "I need to feel like I exist": la barra EXISTENCIA baja sola si nadie le hace caso y él se va volviendo transparente.
# Cada app que abres le hace caso (+12). Clic en él: tu mano le atraviesa. Clic en Orange Cat: se asusta y se sonroja.
# Cada 6 apps: "step into the mist", la niebla rosa lo llena todo.
# Tiempos (cámbialos aquí): cada cuántos ms pierde 1 de existencia
$SfTiempos = @{ Olvido = 2500; CadaNiebla = 6 }
$script:sf = $null
function Sf-Reset {
    if (-not $script:sf) {
        $script:sf = @{ Existe = 80.0; Vis = 80.0; Apps = 0; Manos = 0; Gato = 0; NieblaHasta = 0; NieblaDur = 1; NieblaTope = 150; Avisado = $false
            Prox = [Environment]::TickCount + $SfTiempos.Olvido }
    }
}
function Sf-Existir($n) {
    Sf-Reset; $e = $script:sf
    $e.Existe = [Math]::Max(0.0, [Math]::Min(100.0, $e.Existe + $n))
    if ($e.Existe -gt 30) { $e.Avisado = $false }
}
# niebla rosa que tapa el panel unos milisegundos y se va despejando; $tope = lo opaca que llega a ser (0-255)
function Sf-Niebla($ms, $tope) { Sf-Reset; $script:sf.NieblaHasta = [Environment]::TickCount + $ms; $script:sf.NieblaDur = $ms; $script:sf.NieblaTope = $tope }
# cuánta niebla espesa queda ahora (1 = toda, 0 = nada)
function Sf-Espesor { $e = $script:sf; if (-not $e) { return 0.0 }; $q = ($e.NieblaHasta - [Environment]::TickCount) / [double]$e.NieblaDur; return [Math]::Max(0.0, [Math]::Min(1.0, $q / 0.6)) }
function Sf-App($linea) {
    Sf-Reset; $e = $script:sf; $k = $script:skin
    $e.Apps++; Sf-Existir 12
    if ($e.Apps % $SfTiempos.CadaNiebla -eq 0) {
        Sf-Existir 100; Sf-Niebla 3500 150; Sonido 'viento'; Actor-Pose 'F' 'brazos' 2600
        Decir-Fijo (Azar $k.Niebla)
    } else {
        Sonido 'brillo'; Actor-Pose 'F' 'brazos' 1800; Decir $linea
    }
    $form.Invalidate()
}
function Sf-Clic {
    Sf-Reset; $e = $script:sf; $k = $script:skin
    $e.Manos++; Sf-Existir 5; Sonido 'puff'; Actor-Pose 'F' 'cara' 1300
    Flotante 'FSSSH~' (600 + $Rnd.Next(-30, 30)) 90 (C 255 190 250) 20 'Segoe Print'
    Decir (Azar $k.Clic); $form.Invalidate()
}
function Sf-Gato {
    Sf-Reset; $e = $script:sf; $k = $script:skin
    $e.Gato++; Sonido 'boing'
    $a = $script:actores['G']; if ($a) { $a.Temblor = 10 }
    Flotante '<3' (480 + $Rnd.Next(-20, 20)) 110 (C 255 120 200) 14
    Decir (Azar $k.Gato); $form.Invalidate()
}
function Sf-Tick {
    Sf-Reset; $e = $script:sf; $k = $script:skin; $ahora = [Environment]::TickCount
    if ($ahora -ge $e.Prox) { $e.Prox = $ahora + $SfTiempos.Olvido; Sf-Existir -1 }
    if ($e.Existe -lt 15 -and -not $e.Avisado) { $e.Avisado = $true; Decir (Azar $k.Invisible) }
    # se ve más o menos según lo que existe, y flota de un lado a otro
    $e.Vis += ($e.Existe - $e.Vis) * 0.1
    $a = $script:actores['F']
    if ($a) {
        $a.Alfa = 0.18 + 0.82 * $e.Vis / 100.0
        if ($a.Pose -eq 'main') { $a.Rect = @([int](574 + [Math]::Sin($ahora / 2300.0) * 18), [int](64 + [Math]::Sin($ahora / 1300.0) * 6), 176, 210) }
        else { $a.Rect = @(500, 44, 258, 236) }   # sonrisa y carcajada: de busto y más grandes
    }
    $form.Invalidate()
}
# nubes de niebla rosa que pasan despacio (de $x0 hasta el borde derecho); $fuerza de 0 a 1 (o más, más espesa)
function Pintar-Niebla($g, $x0, $W, $H, $fuerza) {
    if ($fuerza -le 0.01) { return }
    $t = [Environment]::TickCount / 1000.0
    for ($i = 0; $i -lt 7; $i++) {
        $r = 70 + ($i * 37) % 60
        $span = $W - $x0 + 2 * $r
        $x = $x0 - $r + (($i * 131 + $t * (8 + $i * 3)) % $span)
        $y = 60 + ($i * 53) % [Math]::Max(1, $H - 90) + [Math]::Sin($t * 0.7 + $i) * 10
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddEllipse([float]($x - $r * 1.4), [float]($y - $r * 0.7), [float]($r * 2.8), [float]($r * 1.4))
        $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($p)
        $br.CenterColor = [System.Drawing.Color]::FromArgb([int][Math]::Min(255, 150 * $fuerza), 255, 180, 240)
        $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 255, 180, 240))
        $g.FillPath($br, $p); $br.Dispose(); $p.Dispose()
    }
}

# ================= DYBBUK (Mewgenics): VIDA, VOLTERETAS Y POSESIÓN =================
# Barra de vida como la de Guillotina, con la vida del juego (85).
# - Clic en Dybbuk: a veces lo esquiva con una voltereta (su Backflip); si no, le quitas vida. Con menos de la mitad pone su cara de poca vida.
# - Al llegar a 0 aguanta con 1 y posee el panel un momento (en el juego posee a un gato). El siguiente golpe lo mata:
#   los muertos del Boneyard lo arrastran bajo tierra y vuelve a los pocos segundos.
# - Apps: a veces les da un lametazo y les chupa el maná (contador abajo); cada 5 apps invoca fuegos fatuos.
# Tiempos en milisegundos (Esquiva = % de clics que esquiva):
$DyTiempos = @{ Esquiva = 45; AnimPosee = 3300; Posesion = 6000; AnimMuerte = 6600; Vuelve = 6000; Wisps = 4000 }
$script:dy = $null; $script:dyWisp = $null
function Dy-Reset { if (-not $script:dy) { $script:dy = @{ HP = 85; Max = 85; Estado = 'vivo'; Fin = 0; Hasta = 0; Mana = 0; Apps = 0; WispsHasta = 0 } } }
# la pose de reposo según la vida: con menos de la mitad, la de poca vida del juego
function Dy-Base {
    $a = $script:actores['D']; if (-not $a -or -not $script:dy) { return }
    $b = if ($script:dy.HP -le $script:dy.Max / 2) { 'herido' } else { 'main' }
    if ($a.Base -ne $b) { $a.Base = $b; if ($a.Hasta -eq 0) { Actor-Pose 'D' $b 0 } }
}
function Dy-Clic {
    Dy-Reset; $d = $script:dy
    if ($d.Estado -eq 'muerto') { Decir '*Solo queda tierra removida. Algo se mueve ahí debajo.*'; return }
    if ($d.Estado -eq 'posee') { Decir '¡Ñe-he-he! ¡Desde aquí dentro no me pillas!'; return }
    # Backflip: casi la mitad de las veces lo esquiva (en el juego esquiva todos los golpes directos)
    if ($d.HP -gt 1 -and $Rnd.Next(100) -lt $DyTiempos.Esquiva) {
        Actor-Pose 'D' 'flip' 800; Sonido 'flip'
        Flotante '¡ESQUIVA!' $Rnd.Next(480, 580) $Rnd.Next(130, 160) (C 200 225 240) 26 'EdmundMcMillen_INTLv4'
        Decir (Azar $script:skin.Esquiva)
        return
    }
    $dano = $Rnd.Next(6, 15)
    Actor-Golpe 'D'
    Flotante "-$dano" $Rnd.Next(540, 620) $Rnd.Next(120, 160) (C 255 110 120) 32 'EdmundMcMillen_INTLv4'
    if ($d.HP -le 1) { Dy-Muere; return }
    $d.HP -= $dano
    if ($d.HP -le 0) { $d.HP = 1; Dy-Posee; return }   # como en el juego: aguanta con 1 y posee
    Sonido-De 'Guillotina' 'golpe'
    Dy-Base
    Decir "-$dano HP. $(Azar $script:skin.Clic)"
    $form.Invalidate()
}
function Dy-Posee {
    $d = $script:dy; $ahora = [Environment]::TickCount
    $d.Estado = 'posee'; $d.Fin = $ahora + $DyTiempos.AnimPosee; $d.Hasta = $d.Fin + $DyTiempos.Posesion
    Actor-Pose 'D' 'posee' ($DyTiempos.AnimPosee + 200); Sonido 'posee'
    Flotante '¡POSESIÓN!' 470 150 (C 200 170 255) 36 'EdmundMcMillen_INTLv4'
    Decir-Fijo (Azar $script:skin.Posee) $null 1500
    $form.Invalidate()
}
function Dy-Muere {
    $d = $script:dy; $ahora = [Environment]::TickCount
    $d.HP = 0; $d.Estado = 'muerto'; $d.Fin = $ahora + $DyTiempos.AnimMuerte; $d.Hasta = $d.Fin + $DyTiempos.Vuelve
    $a = $script:actores['D']; if ($a) { $a.Base = 'main' }
    Actor-Pose 'D' 'muere' ($DyTiempos.AnimMuerte + 300); Sonido 'muere'
    Flotante 'K.O.' 540 150 (C 255 110 120) 48 'EdmundMcMillen_INTLv4'
    Decir-Fijo (Azar $script:skin.Muere) $null 2500
    $form.Invalidate()
}
function Dy-Wisps {
    Dy-Reset
    Actor-Pose 'D' 'invoca' 2880; Sonido 'wisps'
    $script:dy.WispsHasta = [Environment]::TickCount + $DyTiempos.Wisps
    Flotante '¡FUEGOS FATUOS!' 456 150 (C 140 210 255) 24 'EdmundMcMillen_INTLv4'
    Decir (Azar $script:skin.Wisps)
}
function Dy-App($linea) {
    Dy-Reset; $d = $script:dy; $d.Apps++
    if ($d.Estado -ne 'vivo') { Decir $linea; return }
    if ($d.Apps % 5 -eq 0) { Dy-Wisps; return }
    if ($Rnd.Next(2) -eq 0) {
        # Lick: un lametazo a la app que le chupa el maná
        $m = $Rnd.Next(3, 9); $d.Mana += $m
        Actor-Pose 'D' 'lame' 1840; Sonido 'lame'
        Flotante "+$m MANÁ" $Rnd.Next(470, 540) 150 (C 120 200 255) 24 'EdmundMcMillen_INTLv4'
    }
    Decir $linea
    $form.Invalidate()
}
function Dy-Tick {
    Dy-Reset; $d = $script:dy; $ahora = [Environment]::TickCount
    $a = $script:actores['D']
    if ($d.Estado -ne 'vivo') {
        # al acabar la animación (bajo tierra o dentro del panel) deja de verse
        if ($a -and $a.Visible -and $ahora -ge $d.Fin) { $a.Visible = $false; Invalidar-Escena }
        if ($ahora -ge $d.Hasta) {
            $volvio = $d.Estado -eq 'muerto'
            if ($volvio) { $d.HP = $d.Max }
            $d.Estado = 'vivo'
            if ($a) { $a.Visible = $true; $a.Base = 'main'; Actor-Pose 'D' 'flip' 800 }
            Dy-Base
            if ($volvio) { Sonido 'zombie'; Decir-Fijo (Azar $script:skin.Vuelve) $null 1500 } else { Sonido 'suelta'; Decir-Fijo (Azar $script:skin.Suelta) $null 1500 }
            $form.Invalidate()
        }
        if ($d.Estado -eq 'posee') { Invalidar-Escena }   # el panel late en morado mientras está poseído
    }
    if ($d.WispsHasta -gt 0) { if ($ahora -ge $d.WispsHasta) { $d.WispsHasta = 0 }; Invalidar-Escena }
}
# dibuja una imagen con transparencia (0..1)
function Dy-Img($g, $img, $x, $y, $iw, $ih, $alfa) {
    if (-not $img -or $alfa -le 0) { return }
    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float][Math]::Min(1.0, $alfa)
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle([int]$x, [int]$y, [int]$iw, [int]$ih)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $ia.Dispose()
}

# ================= ELLIE VELÁZQUEZ (self insert de Ale): EL GLITCH =================
# Barra GLITCH = su rabia (0..100). Sube al pincharla y, poco a poco, con el silencio (lo odia). Abrir apps la entretiene (baja un poco).
# Al 100 %: MODO GLITCH (todo rojo, píxeles corruptos, ella partida en colores). Luego se sobrecalienta, se le olvida todo y vuelve a 0.
# Clic en las natillas: se las come y se calma (el cuenco vuelve a llenarse al rato). De vez en cuando se teletransporta o se vuelve invisible.
# Números (rabia por clic, por app, por segundo de silencio) y tiempos en milisegundos:
$ElTiempos = @{ Clic = 17; App = -4; Silencio = 0.4; Glitch = 7000; Natillas = 15000; Tele = 6000; Invisible = 3500; Casa = 614; OtroSitio = 540 }
$script:el = $null; $script:elRojo = $null; $script:elCian = $null
function El-Reset {
    if (-not $script:el) { $script:el = @{ Rabia = 0.0; Glitch = $false; GlitchHasta = 0; Veces = 0; Natillas = 0; NatHasta = 0; TeleHasta = 0; InvHasta = 0; Fx = 0; Bloques = (New-Object System.Collections.ArrayList); UltimoSilencio = 0 } }
}
# píxeles de colores que saltan alrededor de ella (como los de sus fotos)
function El-Bloques($n, $cx, $cy, $rad) {
    if ($script:aj.Epilepsia) { $n = [int]($n / 3) }
    $cols = @((C 255 40 80), (C 90 230 255), (C 255 230 60), (C 150 80 255), (C 90 255 140), (C 255 120 200))
    for ($i = 0; $i -lt $n; $i++) { [void]$script:el.Bloques.Add(@{ X = $cx + $Rnd.Next(-$rad, $rad); Y = $cy + $Rnd.Next(-$rad, $rad); W = $Rnd.Next(5, 22); H = $Rnd.Next(4, 10); C = $cols[$Rnd.Next($cols.Count)]; T = $Rnd.Next(8, 22) }) }
}
function El-Centro { $a = $script:actores['E']; if (-not $a) { return @(680, 170) }; return @(($a.Rect[0] + $a.Rect[2] / 2), ($a.Rect[1] + $a.Rect[3] * 0.45)) }
function El-Rabia($d) {
    El-Reset; $e = $script:el
    $e.Rabia = [Math]::Max(0.0, [Math]::Min(100.0, $e.Rabia + $d))
    if ($e.Rabia -ge 100 -and -not $e.Glitch) { El-Glitch }
}
function El-Glitch {
    $e = $script:el; $e.Glitch = $true; $e.GlitchHasta = [Environment]::TickCount + $ElTiempos.Glitch; $e.Veces++; $e.Fx = 20
    Sonido 'boom'; Sonido 'glitch'; Sacudir $form 16
    $c = El-Centro; El-Bloques 40 $c[0] $c[1] 120
    Decir-Fijo (Azar $script:skin.Glitch) $null 2500
    $form.Invalidate()
}
function El-Fin-Glitch($natillas) {
    $e = $script:el; $e.Glitch = $false; $e.Rabia = 0.0; $e.Fx = 0
    if (-not $natillas) { Decir-Fijo (Azar $script:skin.Olvida) $null 2000 }
    $form.Invalidate()
}
function El-Pinchar {
    El-Reset; $e = $script:el
    if ($e.Glitch) { Decir '*Ni te mira. Está demasiado ocupada corrompiéndolo todo.*'; return }
    $a = $script:actores['E']; if ($a) { $a.Temblor = 8; $a.Alfa = 1.0 }; $e.InvHasta = 0
    $c = El-Centro; El-Bloques 6 $c[0] $c[1] 50
    El-Rabia $ElTiempos.Clic
    if ($e.Glitch) { return }
    if ($e.Rabia -ge 60) { Sonido 'glitch'; Decir (Azar $script:skin.Enfado) } else { Decir (Azar $script:skin.Clic) }
    $form.Invalidate()
}
function El-Natillas {
    El-Reset; $e = $script:el
    $n = $script:actores['N']; if ($n) { $n.Visible = $false }
    $e.NatHasta = [Environment]::TickCount + $ElTiempos.Natillas; $e.Natillas++
    Sonido 'nam'; Flotante '¡ÑAM!' 440 190 (C 255 214 90) 24 'Arial Black'
    if ($e.Glitch) { El-Fin-Glitch $true } else { $e.Rabia = [Math]::Max(0.0, $e.Rabia - 45) }
    Decir-Fijo (Azar $script:skin.Natillas) $null 1200
    $form.Invalidate()
}
function El-Teleport {
    El-Reset; $e = $script:el; $a = $script:actores['E']; if (-not $a) { return }
    $c = El-Centro; El-Bloques 14 $c[0] $c[1] 70
    $x = if ($a.Rect[0] -eq $ElTiempos.Casa) { $ElTiempos.OtroSitio } else { $ElTiempos.Casa }
    $a.Rect = @($x, $a.Rect[1], $a.Rect[2], $a.Rect[3])   # una lista nueva: así no se cambia la ficha de la skin
    $e.TeleHasta = if ($x -eq $ElTiempos.Casa) { 0 } else { [Environment]::TickCount + $ElTiempos.Tele }
    $c = El-Centro; El-Bloques 14 $c[0] $c[1] 70
    Sonido 'tele'; Invalidar-Escena
}
function El-App($linea) {
    El-Reset; El-Rabia $ElTiempos.App
    $c = El-Centro; El-Bloques 4 $c[0] $c[1] 60
    Decir $linea; $form.Invalidate()
}
function El-Tick {
    El-Reset; $e = $script:el; $ahora = [Environment]::TickCount; $cambio = $false
    # el silencio la pone nerviosa: la rabia sube sola (cada tick son 50 ms)
    if (-not $e.Glitch) {
        $antes = [int]$e.Rabia; El-Rabia ($ElTiempos.Silencio / 20.0)
        if ([int]$e.Rabia -ne $antes) { $cambio = $true }
        if ($e.Rabia -ge 75 -and ($ahora - $e.UltimoSilencio) -gt 45000 -and $ahora -ge $script:twBloqueo) { $e.UltimoSilencio = $ahora; Decir (Azar $script:skin.Silencio) }
    } else {
        if (-not $script:aj.Epilepsia -and $Rnd.Next(3) -eq 0) { $c = El-Centro; El-Bloques 3 $c[0] $c[1] 140 }
        if ($ahora -ge $e.GlitchHasta) { El-Fin-Glitch $false }
        $cambio = $true
    }
    if ($e.NatHasta -gt 0 -and $ahora -ge $e.NatHasta) { $e.NatHasta = 0; $n = $script:actores['N']; if ($n) { $n.Visible = $true }; $cambio = $true }
    if ($e.TeleHasta -gt 0 -and $ahora -ge $e.TeleHasta) { El-Teleport }
    if ($e.InvHasta -gt 0 -and $ahora -ge $e.InvHasta) { $e.InvHasta = 0; $a = $script:actores['E']; if ($a) { $a.Alfa = 1.0 }; $cambio = $true }
    if ($e.Fx -gt 0) { $e.Fx--; $cambio = $true }
    if ($e.Bloques.Count -gt 0) { for ($i = $e.Bloques.Count - 1; $i -ge 0; $i--) { $e.Bloques[$i].T--; if ($e.Bloques[$i].T -le 0) { $e.Bloques.RemoveAt($i) } }; $cambio = $true }
    if ($cambio) { $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](266 * $script:K), [int](410 * $script:K), [int](54 * $script:K)))); Invalidar-Escena }
}

# ================= ROARING KNIGHT (Deltarune): FUENTES OSCURAS Y THE ROARING =================
# Cada app que abres es una Fuente Oscura que el Knight saca del suelo: la barra ROARING sube.
# Al llenarse, el Knight ruge (luz roja) y sale un Titán. Clic en el Knight: CHECK / ACT. Botón FIGHT: el minijuego.
$KnTiempos = @{ SubePorApp = 14 }
$script:kn = $null
function Kn-Reset { if (-not $script:kn) { $script:kn = @{ Fuentes = 0; Roaring = 0.0; Titanes = 0; Fx = 0 } } }
function Kn-App($linea) {
    Kn-Reset; $e = $script:kn; $k = $script:skin
    $e.Fuentes++; $e.Roaring = [Math]::Min(100.0, $e.Roaring + $KnTiempos.SubePorApp)
    if ($e.Roaring -ge 100) {
        $e.Roaring = 0.0; $e.Titanes++; $e.Fx = 34
        Sonido 'rugido'; Actor-Pose 'K' 'roar' 1700; Sacudir $form 10
        Decir-Fijo (Azar $k.Roaring)
    } else {
        Sonido 'tajo'; Actor-Pose 'K' 'apunta' 900; Decir $linea
    }
    $form.Invalidate()
}
function Kn-Clic {
    Kn-Reset; $k = $script:skin
    Sonido 'roce'; Actor-Pose 'K' 'risa' 1500
    Decir (Azar $k.Clic)
}
function Kn-Tick { Kn-Reset; if ($script:kn.Fx -gt 0) { $script:kn.Fx--; $form.Invalidate() } }
# el botón FIGHT, dibujado debajo del Knight (como el menú de combate de Deltarune)
function Kn-Fight-Rect { return @(612, 240, 96, 26) }
function Kn-Fight-En-Raton {
    if (-not $script:skin -or $script:skin.Estilo -ne 'knight') { return $false }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K; $r = Kn-Fight-Rect
    return ($x -ge $r[0] -and $x -le ($r[0] + $r[2]) -and $y -ge $r[1] -and $y -le ($r[1] + $r[3]))
}
# caja negra con borde blanco (los cuadros de texto de Deltarune)
function Kn-Caja($g, $x, $y, $w, $h) {
    $g.FillRectangle([System.Drawing.Brushes]::Black, [float]$x, [float]$y, [float]$w, [float]$h)
    $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)), [float]$x, [float]$y, [float]$w, [float]$h)
}
# el ALMA: el corazón rojo de Deltarune
function Kn-Corazon($g, $x, $y, $s, $col) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier([float]$x, [float]($y + $s * 0.9), [float]($x - $s * 1.2), [float]($y + $s * 0.1), [float]($x - $s * 0.9), [float]($y - $s * 0.9), [float]$x, [float]($y - $s * 0.35))
    $p.AddBezier([float]$x, [float]($y - $s * 0.35), [float]($x + $s * 0.9), [float]($y - $s * 0.9), [float]($x + $s * 1.2), [float]($y + $s * 0.1), [float]$x, [float]($y + $s * 0.9))
    $g.FillPath((New-Object System.Drawing.SolidBrush($col)), $p); $p.Dispose()
}

# ================= ROARING KNIGHT: EL MINIJUEGO (un combate de Deltarune) =================
# Botón FIGHT. Mueves el ALMA (corazón rojo) dentro de la caja verde: flechas o WASD (Mayús o X = despacio)
# o arrastrando con el ratón. ESC o HUIR = salir. Tienes 160 HP; cada golpe quita 40. Rozar los ataques sube el TP.
# Ataques del capítulo 3: espadas que te persiguen y cortan, estrellas que explotan y espadas rápidas al final.
# Momentos (ms desde que empieza) y valores: cámbialos aquí para hacerlo más fácil o más difícil.
$KgTiempos = @{ Espadas1 = 1800; Estrellas = 11000; Explota = 13800; Espadas2 = 17200; Fin = 23000; Dano = 40; HP = 160; Vel = 140 }
$KgCaja = @{ X = 222; Y = 84; W = 156; H = 156 }
$script:kg = $null; $script:kgOv = $null
function Kg-Teclas {
    if (-not ('C00l.Teclas' -as [type])) {
        try { Add-Type -Namespace C00l -Name Teclas -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);' } catch {}
    }
}
function Kg-Tecla($vk) { try { return (([C00l.Teclas]::GetAsyncKeyState($vk) -band 0x8000) -ne 0) } catch { return $false } }
function Kg-Espada($nace, $sigue) {
    [void]$script:kg.Espadas.Add(@{ Nace = $nace; Sigue = $sigue; Ang = $Rnd.Next(8) * [Math]::PI / 4; Estado = 'espera'; PX = 0.0; PY = 0.0 })
}
function Kn-Combate {
    if (Ocupado) { return }
    Kg-Teclas
    $script:transicion = $true
    $KT = $KgTiempos
    $script:kg = @{ T0 = [Environment]::TickCount; Ultimo = [Environment]::TickCount; X = [double]($KgCaja.X + $KgCaja.W / 2); Y = [double]($KgCaja.Y + $KgCaja.H / 2)
        HP = $KT.HP; TP = 0.0; Inv = 0; UltRoce = 0; Sacude = 0; Fin = $null; FinT = 0; Raton = $false; RX = 0.0; RY = 0.0
        Espadas = New-Object System.Collections.ArrayList; Estrellas = New-Object System.Collections.ArrayList; Trozos = New-Object System.Collections.ArrayList
        EstrellasHechas = $false; Explotadas = $false }
    # primera tanda: 8 espadas, cada vez más rápidas; última tanda: 10 espadas muy rápidas que se solapan
    $t = $KT.Espadas1; foreach ($s in @(1000, 940, 880, 820, 760, 700, 640, 580)) { Kg-Espada $t $s; $t += $s + 260 }
    $t = $KT.Espadas2; foreach ($s in @(560, 540, 520, 500, 480, 460, 440, 420, 400, 380)) { Kg-Espada $t $s; $t += [int]($s * 0.62) }
    $script:kgImgs = @{}; $script:kgInfo = @{}
    foreach ($n in @('knight', 'roar', 'apunta', 'risa')) { $im = Cargar-Img "skins\knight\$n.gif"; if ($im) { $script:kgImgs[$n] = $im; $script:kgInfo[$n] = Gif-Info $im } }
    $script:kgImgs['brazos'] = Cargar-Img 'skins\knight\brazos.png'; $script:kgInfo['brazos'] = @{ N = 1; Del = @(100) }
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0); $ov.Size = $form.ClientSize; $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $ov.Add_Paint({ $_.Graphics.ScaleTransform($script:K, $script:K); Kg-Pintar $_.Graphics ([int]($this.Width / $script:K)) ([int]($this.Height / $script:K)) })
    $ov.Add_MouseDown({ if ($script:kg.Fin) { Kg-Salir } else { $script:kg.Raton = $true; $script:kg.RX = $_.X / $script:K; $script:kg.RY = $_.Y / $script:K } })
    $ov.Add_MouseMove({ if ($script:kg -and $script:kg.Raton) { $script:kg.RX = $_.X / $script:K; $script:kg.RY = $_.Y / $script:K } })
    $ov.Add_MouseUp({ if ($script:kg) { $script:kg.Raton = $false } })
    # botón HUIR (como huir de un combate)
    $hu = New-Object System.Windows.Forms.Button
    $hu.Text = 'HUIR'; $hu.FlatStyle = 'Flat'; $hu.Font = Fnt('Consolas', 9, [System.Drawing.FontStyle]::Bold)
    $hu.ForeColor = [System.Drawing.Color]::White; $hu.BackColor = [System.Drawing.Color]::Black; $hu.Cursor = 'Hand'
    $hu.FlatAppearance.BorderColor = [System.Drawing.Color]::White; $hu.FlatAppearance.MouseOverBackColor = (C 60 40 0)
    $hu.Size = New-Object System.Drawing.Size([int](70 * $script:K), [int](24 * $script:K))
    $hu.Location = New-Object System.Drawing.Point(($ov.Width - $hu.Width - [int](12 * $script:K)), ($ov.Height - $hu.Height - [int](10 * $script:K)))
    $hu.Add_Click({ Kg-Salir })
    $ov.Controls.Add($hu)
    $form.Controls.Add($ov); $ov.BringToFront(); $ov.Focus() | Out-Null
    $script:kgOv = $ov
    Sonido 'encuentro'; Sonido 'rugido'
    $kgTimer.Start()
}
function Kg-Dano {
    $e = $script:kg; $ahora = [Environment]::TickCount
    if ($ahora -lt $e.Inv -or $e.Fin) { return }
    $e.HP = [Math]::Max(0, $e.HP - $KgTiempos.Dano); $e.Inv = $ahora + 1000
    Sonido 'golpe'; if (-not $script:aj.Epilepsia) { $e.Sacude = 8 }
    if ($e.HP -le 0) { $e.Fin = 'derrota'; $e.FinT = $ahora }
}
function Kg-Roce {
    $e = $script:kg; $ahora = [Environment]::TickCount
    if ($ahora -lt $e.Inv) { return }
    $e.TP = [Math]::Min(100.0, $e.TP + 1.5)
    if ($ahora - $e.UltRoce -gt 220) { $e.UltRoce = $ahora; Sonido 'roce' }
}
function Kg-Tick {
    $e = $script:kg; if (-not $e) { return }
    $ahora = [Environment]::TickCount; $t = $ahora - $e.T0; $dt = [Math]::Min(60, $ahora - $e.Ultimo) / 1000.0; $e.Ultimo = $ahora
    if ($e.Sacude -gt 0) { $e.Sacude-- }
    if ($e.Fin) { if ($ahora - $e.FinT -gt 3600) { Kg-Salir }; return }
    $KT = $KgTiempos; $c = $KgCaja
    # --- mover el ALMA: teclado (solo si el panel está activo) o ratón arrastrando ---
    $vx = 0; $vy = 0; $despacio = $false
    if ([System.Windows.Forms.Form]::ActiveForm -eq $form) {
        if ((Kg-Tecla 0x25) -or (Kg-Tecla 0x41)) { $vx-- }
        if ((Kg-Tecla 0x27) -or (Kg-Tecla 0x44)) { $vx++ }
        if ((Kg-Tecla 0x26) -or (Kg-Tecla 0x57)) { $vy-- }
        if ((Kg-Tecla 0x28) -or (Kg-Tecla 0x53)) { $vy++ }
        $despacio = (Kg-Tecla 0x10) -or (Kg-Tecla 0x58)
        if (Kg-Tecla 0x1B) { Kg-Salir; return }
    }
    $vel = $KT.Vel * $(if ($despacio) { 0.5 } else { 1.0 })
    if ($vx -ne 0 -or $vy -ne 0) {
        $n = [Math]::Sqrt($vx * $vx + $vy * $vy); $e.X += $vx / $n * $vel * $dt; $e.Y += $vy / $n * $vel * $dt
    } elseif ($e.Raton) {
        $dx = $e.RX - $e.X; $dy = $e.RY - $e.Y; $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
        if ($d -gt 1) { $paso = [Math]::Min($d, $vel * 1.3 * $dt); $e.X += $dx / $d * $paso; $e.Y += $dy / $d * $paso }
    }
    $e.X = [Math]::Max($c.X + 8, [Math]::Min($c.X + $c.W - 8, $e.X)); $e.Y = [Math]::Max($c.Y + 8, [Math]::Min($c.Y + $c.H - 8, $e.Y))
    # --- espadas que te persiguen: siguen al alma, se ponen rojas, se quedan quietas y cortan en línea recta ---
    foreach ($s in $e.Espadas) {
        if ($t -lt $s.Nace -or $s.Estado -eq 'fin') { continue }
        $f = $t - $s.Nace
        if ($f -lt $s.Sigue) { $s.Estado = 'sigue'; $s.PX = $e.X + [Math]::Cos($s.Ang) * 58; $s.PY = $e.Y + [Math]::Sin($s.Ang) * 58 }
        elseif ($f -lt $s.Sigue + 220) { if ($s.Estado -ne 'rojo') { $s.Estado = 'rojo'; Sonido 'aviso' } }
        elseif ($f -lt $s.Sigue + 400) {
            if ($s.Estado -ne 'tajo') { $s.Estado = 'tajo'; Sonido 'tajo' }
            $dl = [Math]::Abs(($e.X - $s.PX) * [Math]::Sin($s.Ang) - ($e.Y - $s.PY) * [Math]::Cos($s.Ang))
            if ($dl -lt 6) { Kg-Dano } elseif ($dl -lt 20) { Kg-Roce }
        } else { $s.Estado = 'fin' }
    }
    # --- estrellas: salen del dedo del Knight, crecen, se paran, se ponen rojas y explotan en 6 trozos ---
    if ($t -ge $KT.Estrellas -and -not $e.EstrellasHechas) {
        $e.EstrellasHechas = $true; Sonido 'estrella'
        for ($i = 0; $i -lt 7; $i++) {
            $ox = 486; $oy = 118; $tx = $c.X + 14 + $Rnd.Next($c.W - 28); $ty = $c.Y + 14 + $Rnd.Next($c.H - 28)
            [void]$e.Estrellas.Add(@{ X = [double]$ox; Y = [double]$oy; VX = ($tx - $ox) / 2.3; VY = ($ty - $oy) / 2.3; R = 3.0; Retraso = $i * 160 })
        }
    }
    if ($e.EstrellasHechas -and -not $e.Explotadas) {
        foreach ($st in $e.Estrellas) {
            if ($t - $KT.Estrellas -lt $st.Retraso) { continue }
            if ($t -lt $KT.Explota - 800) { $st.X += $st.VX * $dt; $st.Y += $st.VY * $dt; $st.R = [Math]::Min(10.0, $st.R + 4 * $dt) }
            else { $st.X -= $st.VX * 0.25 * $dt; $st.Y -= $st.VY * 0.25 * $dt }
            $d = [Math]::Sqrt(($e.X - $st.X) * ($e.X - $st.X) + ($e.Y - $st.Y) * ($e.Y - $st.Y))
            if ($d -lt 4) { Kg-Dano } elseif ($d -lt 16) { Kg-Roce }
        }
        if ($t -ge $KT.Explota) {
            $e.Explotadas = $true; Sonido 'explota'
            foreach ($st in $e.Estrellas) { $gir = $Rnd.NextDouble(); for ($k = 0; $k -lt 6; $k++) { $a = ($k + $gir) * [Math]::PI / 3; [void]$e.Trozos.Add(@{ X = $st.X; Y = $st.Y; VX = [Math]::Cos($a) * 46; VY = [Math]::Sin($a) * 46; Vida = 1600 }) } }
            $e.Estrellas.Clear()
        }
    }
    for ($i = $e.Trozos.Count - 1; $i -ge 0; $i--) {
        $tr = $e.Trozos[$i]; $tr.X += $tr.VX * $dt; $tr.Y += $tr.VY * $dt; $tr.Vida -= $dt * 1000
        if ($tr.Vida -le 0) { $e.Trozos.RemoveAt($i); continue }
        $d = [Math]::Sqrt(($e.X - $tr.X) * ($e.X - $tr.X) + ($e.Y - $tr.Y) * ($e.Y - $tr.Y))
        if ($d -lt 5) { Kg-Dano } elseif ($d -lt 15) { Kg-Roce }
    }
    # --- aguantar hasta el final = victoria ---
    if ($t -ge $KT.Fin -and $e.HP -gt 0) {
        $e.Fin = 'victoria'; $e.FinT = $ahora; Sonido 'victoria'
        $script:aj.KnightVictorias = [int]$script:aj.KnightVictorias + 1; Guardar-Ajustes
    }
}
function Kg-Pintar($g, $W, $H) {
    $e = $script:kg; if (-not $e) { return }
    $KT = $KgTiempos; $c = $KgCaja; $ahora = [Environment]::TickCount; $t = $ahora - $e.T0
    $g.Clear([System.Drawing.Color]::Black)
    $ox = 0; $oy = 0; if ($e.Sacude -gt 0) { $ox = $Rnd.Next(-3, 4); $oy = $Rnd.Next(-3, 4) }
    $g.TranslateTransform($ox, $oy)
    # cuadrícula morada del fondo de combate
    $pg = New-Object System.Drawing.Pen((C 38 12 60), 1); $desp = ($t / 60) % 30
    for ($x = - 30 + $desp; $x -lt $W; $x += 30) { $g.DrawLine($pg, [float]$x, 0, [float]$x, $H) }
    for ($y = - 30 + $desp; $y -lt $H; $y += 30) { $g.DrawLine($pg, 0, [float]$y, $W, [float]$y) }
    # el Knight (pixel art, sin suavizar), con la pose según el momento
    $pose = if ($e.Fin -eq 'victoria') { 'brazos' } elseif ($e.Fin -eq 'derrota') { 'risa' } elseif ($t -lt $KT.Espadas1) { 'roar' } elseif ($t -ge $KT.Estrellas - 300 -and $t -lt $KT.Explota + 600) { 'apunta' } else { 'knight' }
    $img = $script:kgImgs[$pose]
    if ($img) {
        Gif-Frame $img $script:kgInfo[$pose] $t
        $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
        $s = 1.5; $iw = $img.Width * $s; $ih = $img.Height * $s
        $g.DrawImage($img, [float](600 - $iw / 2), [float](168 - $ih / 2), [float]$iw, [float]$ih)
        $g.InterpolationMode = 'HighQualityBilinear'; $g.PixelOffsetMode = 'Default'
    }
    $g.SmoothingMode = 'AntiAlias'
    # la caja verde del combate
    $g.FillRectangle([System.Drawing.Brushes]::Black, $c.X, $c.Y, $c.W, $c.H)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 200 0), 3)), $c.X, $c.Y, $c.W, $c.H)
    # espadas
    $blanco = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1.5); $rojoP = New-Object System.Drawing.Pen((C 255 40 40), 1.5)
    foreach ($s in $e.Espadas) {
        if ($s.Estado -in @('sigue', 'rojo')) {
            $dx = - [Math]::Cos($s.Ang); $dy = - [Math]::Sin($s.Ang); $nx = - $dy; $ny = $dx
            $pts = [System.Drawing.PointF[]]@(
                (New-Object System.Drawing.PointF([float]($s.PX + $dx * 17), [float]($s.PY + $dy * 17))),
                (New-Object System.Drawing.PointF([float]($s.PX + $nx * 3.5), [float]($s.PY + $ny * 3.5))),
                (New-Object System.Drawing.PointF([float]($s.PX - $dx * 12), [float]($s.PY - $dy * 12))),
                (New-Object System.Drawing.PointF([float]($s.PX - $nx * 3.5), [float]($s.PY - $ny * 3.5))))
            $rojo = $s.Estado -eq 'rojo'
            $g.FillPolygon($(if ($rojo) { (New-Object System.Drawing.SolidBrush((C 120 0 0))) } else { [System.Drawing.Brushes]::Black }), $pts)
            $g.DrawPolygon($(if ($rojo) { $rojoP } else { $blanco }), $pts)
            # la guarda de la espada
            $gx = $s.PX - $dx * 8; $gy = $s.PY - $dy * 8
            $g.DrawLine($(if ($rojo) { $rojoP } else { $blanco }), [float]($gx + $nx * 7), [float]($gy + $ny * 7), [float]($gx - $nx * 7), [float]($gy - $ny * 7))
        } elseif ($s.Estado -eq 'tajo') {
            $q = [Math]::Max(0.0, 1 - ($t - $s.Nace - $s.Sigue - 220) / 180.0)
            $g.SetClip((New-Object System.Drawing.RectangleF([float]$c.X, [float]$c.Y, [float]$c.W, [float]$c.H)))
            $pt = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int](255 * $q), 255, 255, 255), [float](2 + 9 * $q))
            $cx = [Math]::Cos($s.Ang); $cy = [Math]::Sin($s.Ang)
            $g.DrawLine($pt, [float]($s.PX - $cx * 400), [float]($s.PY - $cy * 400), [float]($s.PX + $cx * 400), [float]($s.PY + $cy * 400))
            $g.ResetClip(); $pt.Dispose()
        }
    }
    # estrellas de seis puntas y sus trozos
    $rojas = $t -ge $KT.Explota - 800
    foreach ($st in $e.Estrellas) {
        if ($t - $KT.Estrellas -lt $st.Retraso) { continue }
        $pts = New-Object 'System.Drawing.PointF[]' 12
        for ($k = 0; $k -lt 12; $k++) { $r = if ($k % 2 -eq 0) { $st.R } else { $st.R * 0.5 }; $a = $k * [Math]::PI / 6 + $t / 400.0; $pts[$k] = New-Object System.Drawing.PointF([float]($st.X + [Math]::Cos($a) * $r), [float]($st.Y + [Math]::Sin($a) * $r)) }
        $g.FillPolygon([System.Drawing.Brushes]::Black, $pts); $g.DrawPolygon($(if ($rojas) { $rojoP } else { $blanco }), $pts)
        $g.FillEllipse([System.Drawing.Brushes]::White, [float]($st.X - 1.5), [float]($st.Y - 1.5), 3, 3)
    }
    foreach ($tr in $e.Trozos) {
        $al = [int][Math]::Min(255, $tr.Vida / 4)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 255, 255, 255))), [float]($tr.X - 3), [float]($tr.Y - 3), 6, 6)
    }
    # el ALMA (parpadea un poco tras recibir un golpe; en modo seguro solo se aclara)
    $inv = $ahora -lt $e.Inv
    if (-not $e.Fin -or $e.Fin -eq 'victoria') {
        if ($inv -and $script:aj.Epilepsia) { Kn-Corazon $g $e.X $e.Y 7 ([System.Drawing.Color]::FromArgb(140, 255, 0, 0)) }
        elseif (-not $inv -or ([int]($ahora / 90) % 2 -eq 0)) { Kn-Corazon $g $e.X $e.Y 7 ([System.Drawing.Color]::Red) }
    }
    $g.ResetTransform(); $g.ScaleTransform($script:K, $script:K)
    # TP a la izquierda (sube rozando los ataques)
    $g.DrawString('TP', (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 30, 66)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 20 0))), 36, 90, 16, 160)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 160 64))), 36, [float](90 + 160 * (1 - $e.TP / 100.0)), 16, [float](160 * $e.TP / 100.0))
    $g.DrawRectangle([System.Drawing.Pens]::White, 36, 90, 16, 160)
    $g.DrawString("$([int]$e.TP)%", (FntP('Consolas', 9, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 160 64))), 28, 254)
    # la vida de Kris abajo
    Kn-Caja $g 150 266 300 40
    $g.DrawString('KRIS', (FntP('Consolas', 12, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 0 200 255))), 160, 276)
    $g.DrawString('HP', (FntP('Consolas', 9, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 226, 280)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 0 0))), 250, 282, 110, 10)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 200 255))), 250, 282, [float](110 * [Math]::Min(1.0, $e.HP / $KT.HP)), 10)
    $g.DrawString("$($e.HP)/$($KT.HP)", (FntP('Consolas', 10, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 368, 278)
    # texto del combate arriba
    $txt = '* Tu vista se estrecha. ...El mundo gira a tu alrededor.'
    if ($e.Fin -eq 'victoria') { $txt = '* ¡Has aguantado! * El Knight cruza los brazos... y se va volando.' }
    elseif ($e.Fin -eq 'derrota') { $txt = '* Kris quedó DOWN. * El Knight se ríe.' }
    elseif ($t -lt $KT.Espadas1) { $txt = '* The Roaring Knight appeared.' }
    elseif ($t -lt $KT.Estrellas) { $txt = '* Notas algo flotando justo detrás de tu cabeza...' }
    elseif ($t -lt $KT.Espadas2) { $txt = '* Te mareas. Ves estrellas doradas...' }
    Kn-Caja $g 12 10 ($W - 24) 50
    $g.DrawString($txt, (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(22, 16, [float]($W - 44), 42)))
    # resultado
    if ($e.Fin) {
        $gana = $e.Fin -eq 'victoria'
        $big = if ($gana) { 'VICTORIA' } else { 'DOWN' }
        $tw = Ancho-Texto $big 'Consolas' 34
        Texto-Color $g $big 'Consolas' 34 ($W / 2 - $tw / 2 - 40) 112 $(if ($gana) { (C 255 255 0) } else { (C 255 40 40) }) (C 0 0 0) 6
        $g.DrawString("victorias contra el Knight: $($script:aj.KnightVictorias)", (FntP('Consolas', 10, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 170, 168)
        $g.DrawString('(clic para salir)', (FntP('Consolas', 9)), (New-Object System.Drawing.SolidBrush((C 180 180 180))), 236, 188)
    } else {
        $g.DrawString('flechas / WASD · Mayús = despacio · o arrastra con el ratón · ESC', (FntP('Consolas', 7.5)), (New-Object System.Drawing.SolidBrush((C 150 150 150))), 150, 246)
    }
}
function Kg-Salir {
    $kgTimer.Stop()
    if ($script:kgOv) { $form.Controls.Remove($script:kgOv); $script:kgOv.Dispose(); $script:kgOv = $null }
    foreach ($im in @($script:kgImgs.Values)) { if ($im) { $im.Dispose() } }
    $script:kgImgs = @{}
    $script:transicion = $false
    $e = $script:kg; $k = $script:skin; $script:kg = $null
    if ($e -and $e.Fin -eq 'victoria') { Actor-Pose 'K' 'risa' 2500; Decir (Azar $k.Gana) }
    elseif ($e -and $e.Fin -eq 'derrota') { Actor-Pose 'K' 'risa' 2500; Decir (Azar $k.Pierde) }
    else { Decir '* Has huido del combate. * El Knight ni se ha movido.' }
    $form.Invalidate()
}
$kgTimer = New-Object System.Windows.Forms.Timer
$kgTimer.Interval = 20
$kgTimer.Add_Tick({
    try { if ($script:kg) { Kg-Tick; if ($script:kgOv) { $script:kgOv.Invalidate() } } }
    catch { Add-Content "$env:TEMP\c00lgui_errores.txt" ("KNIGHT: " + $_ + " @ " + $_.InvocationInfo.ScriptLineNumber); Kg-Salir }
})

# ================= DISCUSIONES ENTRE ASISTENTES =================
# cada discusión es una lista de [quién, qué dice]. Solo salen las de la skin activa.
$Discusiones = @()
# ================= DIÁLOGOS: SE CARGAN DE LA CARPETA "dialogos" =================
# Las frases de cada skin (Hola, Yo, Frases, Idle, Clic, PorApp, AlVenirDe, Opina y las de sus mecánicas)
# están en dialogos\<nombre de la skin>.json, y las charlas entre skins en dialogos\_charlas.json.
# Se pueden editar con cualquier editor de texto (guardar en UTF-8). Antes de escribir, mira la ficha del personaje en lore\.
$CarpetaDialogos = Join-Path $Raiz 'dialogos'
# convierte lo que lee ConvertFrom-Json en tablas y listas normales de PowerShell (las listas siguen siendo listas aunque tengan 1 frase)
function Json-A-Datos($o) {
    if ($null -eq $o -or $o -is [string]) { return $o }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = Json-A-Datos $p.Value }; return $h
    }
    if ($o -is [array]) {
        $l = New-Object System.Collections.ArrayList
        foreach ($x in $o) { [void]$l.Add((Json-A-Datos $x)) }
        return , ($l.ToArray())
    }
    return $o
}
function Cargar-Dialogos {
    foreach ($n in @($Skins.Keys)) {
        $f = Join-Path $CarpetaDialogos "$n.json"
        if (-not (Test-Path -LiteralPath $f)) { continue }
        try {
            $d = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($p in $d.PSObject.Properties) { $Skins[$n][$p.Name] = Json-A-Datos $p.Value }
        } catch { Add-Content "$env:TEMP\c00lgui_errores.txt" "DIALOGOS ${n}: $_" }
    }
    $f = Join-Path $CarpetaDialogos '_charlas.json'
    if (Test-Path -LiteralPath $f) {
        try { $d = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json; $script:Discusiones = Json-A-Datos $d.charlas }
        catch { Add-Content "$env:TEMP\c00lgui_errores.txt" "CHARLAS: $_" }
    }
}
Cargar-Dialogos

$script:discutiendo = $false; $script:dLineas = $null; $script:dIdx = 0; $script:dImg = $null; $script:dInvitadoHabla = $false
$script:dFin = 0; $script:dUltima = $null
$script:inv = $null; $script:invSkin = $null; $script:invNombre = $null; $script:invPb = $null; $script:invLbl = $null
$script:invTexto = ''; $script:invPos = 0; $script:invFx = 0; $script:invAnim = 0; $script:invLado = 1; $script:invSale = $false
$script:invEst = 0; $script:invRuido = $null
$dTimer = New-Object System.Windows.Forms.Timer
$dTimer.Add_Tick({ Paso-Discusion })

# --- temblores de ventana ---
$script:temblores = New-Object System.Collections.ArrayList
$shkTimer = New-Object System.Windows.Forms.Timer
$shkTimer.Interval = 30
$shkTimer.Add_Tick({
    for ($i = $script:temblores.Count - 1; $i -ge 0; $i--) {
        $s = $script:temblores[$i]; $s.T--
        if ($s.F.IsDisposed) { $script:temblores.RemoveAt($i); continue }
        if ($s.T -le 0) { $s.F.Location = $s.Base; $script:temblores.RemoveAt($i) }
        else { $a = [int](4 * $script:K); $s.F.Location = New-Object System.Drawing.Point(($s.Base.X + $Rnd.Next(-$a, $a + 1)), ($s.Base.Y + $Rnd.Next(-$a, $a + 1))) }
    }
    if ($script:temblores.Count -eq 0) { $shkTimer.Stop() }
})
function Sacudir($f, $ticks) {
    if ($script:aj.Epilepsia) { return }   # modo seguro: nada tiembla
    if (-not $f -or $f.IsDisposed -or $script:glitching -or $script:drag) { return }
    foreach ($s in $script:temblores) { if ($s.F -eq $f) { $s.T = [Math]::Max($s.T, $ticks); return } }
    [void]$script:temblores.Add(@{ F = $f; Base = $f.Location; T = $ticks }); $shkTimer.Start()
}
$script:humoF = $null
$humo2Timer = New-Object System.Windows.Forms.Timer
$humo2Timer.Interval = 1600
$humo2Timer.Add_Tick({ $humo2Timer.Stop(); if ($script:humoF -and -not $script:humoF.IsDisposed) { $script:humoF.Opacity = $(if ($script:humoF -eq $form) { (Opacidad-Base) } else { 0.99 }); $script:humoF.Invalidate($true) } })
function Humo($f) { if (-not $f) { return }; $f.Opacity = 0.3; $script:humoF = $f; $humo2Timer.Stop(); $humo2Timer.Start() }

# --- ventanita del invitado ---
function Colocar-Invitado {
    $f = $script:inv; if (-not $f -or $f.IsDisposed) { return }
    $b = $form.Bounds; $e = 1 - [Math]::Pow(1 - [Math]::Min(1.0, $script:invAnim / 10.0), 3)
    $off = (1 - $e) * 40 * $script:K
    $x = if ($script:invLado -gt 0) { $b.Right + 8 * $script:K - $off } else { $b.Left - $f.Width - 8 * $script:K + $off }
    $f.Location = New-Object System.Drawing.Point([int]$x, [int]($b.Top + 30 * $script:K))
    $f.Opacity = [Math]::Min(0.99, [Math]::Max(0.0, $e))
    $f.Invalidate($true)
}

function Abrir-Invitado($nombre) {
    $gk = $Skins[$nombre]; $script:invSkin = $gk; $script:invNombre = $nombre
    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'; $f.ShowInTaskbar = $false; $f.StartPosition = 'Manual'; $f.Text = 'invitado'
    $f.Size = New-Object System.Drawing.Size(220, 214); $f.BackColor = $gk.Fondo; $f.Opacity = 0
    Doble-Buffer $f
    $script:invPb = $null
    if ($gk.Gif -and $script:dImg) {
        $p = New-Object System.Windows.Forms.PictureBox
        $p.Location = New-Object System.Drawing.Point(10, 36); $p.Size = New-Object System.Drawing.Size(200, 108)
        $p.SizeMode = 'Zoom'; $p.Image = $script:dImg
        $p.BackColor = if ($gk.PbFondo) { $gk.PbFondo } else { [System.Drawing.Color]::Transparent }
        $f.Controls.Add($p); $script:invPb = $p
    }
    $l = New-Object System.Windows.Forms.Label
    $l.Location = New-Object System.Drawing.Point(10, 150); $l.Size = New-Object System.Drawing.Size(200, 56)
    $l.BackColor = if ($gk.BurFondo) { $gk.BurFondo } elseif ($gk.InvFondo) { $gk.InvFondo } else { [System.Drawing.Color]::Black }
    if ($script:fuentesPriv.ContainsKey([string]$gk.BurFuente)) { $l.UseCompatibleTextRendering = $true }
    $l.ForeColor = if ($gk.BurTexto) { $gk.BurTexto } else { $gk.StatusColor }
    $fb = if ($gk.BurFuente) { $gk.BurFuente } else { 'Consolas' }
    $l.Font = Fnt($fb, $(if ($fb -eq 'Segoe Print') { 7.5 } else { 8.5 }), [System.Drawing.FontStyle]::Bold)
    $l.BorderStyle = 'FixedSingle'; $l.Padding = New-Object System.Windows.Forms.Padding(3)
    $f.Controls.Add($l); $script:invLbl = $l
    $f.Add_Paint({ Pintar-Invitado $_.Graphics })
    Escalar $f
    $f.Owner = $form
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $script:invLado = if ($form.Right + $f.Width + 12 -le $wa.Right) { 1 } else { -1 }
    $script:invTamBase = $null
    $script:inv = $f; $script:invAnim = 0; $script:invSale = $false; $script:invFx = 14; $script:invTexto = ''; $script:invPos = 0
    Colocar-Invitado
    $f.Show()
    # cada invitado llega con su propio sonido
    switch ($gk.Estilo) {
        'oeste' { Sonido-De $nombre 'bang' }
        'mew' { Sonido-De $nombre 'golpe' }
        'mlg' { Sonido-De $nombre 'apuntar' }
        'culto' { Sonido-De $nombre 'balido' }
        'kaiju' { Sonido-De $nombre 'pisoton' }
        'zorro' { Sonido-De $nombre 'yip' }
        'teto' { Sonido-De $nombre 'hi' }
        'enfosi' { Sonido-De $nombre 'ding' }
        'femta' { Sonido-De $nombre 'golpe' }
        'pop' { Sonido-De $nombre 'ping' }
        'pizza' { Sonido-De $nombre 'nam' }
        'punk' { Sonido-De $nombre 'acorde' }
        'gran' { }   # llega en silencio: su único sonido es su canción
        'abismo' { Sonido-De $nombre 'brillo' }
        'historia' { Sonido-De $nombre 'pagina' }
        'lobo' { Sonido-De $nombre 'pebox' }
        'arana' { Sonido-De $nombre 'siseo' }
        'clima' { Sonido-De $nombre 'gota' }
        'pintor' { Sonido-De $nombre 'blip' }
        'evil' { Sonido-De $nombre 'medio' }
        'niebla' { Sonido-De $nombre 'brillo' }
        'knight' { Sonido-De $nombre 'encuentro' }
        'corrupta' { Sonido-De $nombre 'tele' }
        'boneyard' { Sonido-De $nombre 'flip' }
        'pressure' { Sonido-De $nombre 'rejilla' }
        'dod' { Sonido-De $nombre 'acecho' }
        'hacker' { try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Hand.Play() } } catch {} }
        default { try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Asterisk.Play() } } catch {} }
    }
    $invTimer.Start()
}

function Pintar-Invitado($g) {
    $g.ScaleTransform($script:K, $script:K); $g.SmoothingMode = 'AntiAlias'
    $gk = $script:invSkin; $W = 220; $H = 214; $fx = $script:invFx
    if (-not $gk) { return }
    $g.Clear($gk.Fondo)
    # fondo y cabecera con el estilo del invitado
    $cab = $gk.Fondo
    switch ($gk.Estilo) {
        'hacker' { $p = New-Object System.Drawing.Pen((C 30 0 0), 1); for ($y = 30; $y -lt $H; $y += 4) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 0 0 0) }
        'web' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, 31)), $gk.Barra1, $gk.Barra2, 90); $g.FillRectangle($br, 0, 0, $W, 31); $cab = $null }
        'tele' { $lun = New-Object System.Drawing.SolidBrush((C 255 95 70)); for ($y = 36; $y -lt $H; $y += 18) { for ($x = 4; $x -lt $W; $x += 18) { $g.FillEllipse($lun, $x, $y, 5, 5) } }; $cab = (C 58 44 190) }
        'mew' { for ($x = 0; $x -lt $W; $x += 20) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 62 44 52))), $x, 30, 10, $H) }; $cab = (C 28 21 24) }
        'lobo' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 24 32 42), (C 8 10 14), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $tl = New-Object System.Drawing.Pen((ARGB 60 80 210 200), 1); for ($y = 40; $y -lt $H; $y += 8) { $g.DrawLine($tl, 0, $y, $W, $y) }; $tl.Dispose(); $cab = (C 14 18 24) }
        'mlg' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (C 57 72 191), (C 229 45 45), 35); $g.FillRectangle($br, 0, 0, $W, $H); $cab = (C 14 14 28) }
        'oeste' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 238 128 62), (C 250 214 150), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 90 52 28) }
        'gunsaw' { $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, 255, 255, 255), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 18 9 22) }
        'culto' { $p = New-Object System.Drawing.Pen((C 110 24 34), 2); $g.DrawEllipse($p, 40, 30, 140, 140); $g.DrawEllipse($p, 50, 40, 120, 120); $cab = (C 14 8 10) }
        'kaiju' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 18 60), (C 220 96 52), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 12 8 10) }
        'pressure' { $p = New-Object System.Drawing.Pen((C 30 60 66), 1); for ($y = 34; $y -lt $H; $y += 6) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 8 10 14) }
        'dod' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 4 16 10), (C 10 40 26), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 4 8 6) }
        'zorro' { $pu = New-Object System.Drawing.SolidBrush((C 250 222 190)); for ($y = 40; $y -lt $H; $y += 18) { for ($x = (($y / 18) % 2) * 9 + 4; $x -lt $W; $x += 18) { $g.FillEllipse($pu, $x, $y, 5, 5) } }; $cab = (C 230 128 56) }
        'femta' { $rn = New-Object System.Random 5; for ($i = 0; $i -lt 30; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $rn.Next(30, 90) 230 20 40))), 0, $rn.Next(30, $H), $W, $rn.Next(1, 3)) }; $cab = (C 0 0 0) }
        'pop' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 14 80), (C 150 40 120), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $p = New-Object System.Drawing.Pen((ARGB 30 0 0 0), 1); for ($y = 30; $y -lt $H; $y += 3) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 40 12 70) }
        'gran' { $rosa = New-Object System.Drawing.SolidBrush((ARGB 60 255 70 170)); for ($x = -$H; $x -lt $W; $x += 30) { $g.FillPolygon($rosa, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, $H)), (New-Object System.Drawing.PointF([float]($x + 12), $H)), (New-Object System.Drawing.PointF([float]($x + 12 + $H), 30)), (New-Object System.Drawing.PointF([float]($x + $H), 30)))) }; $rosa.Dispose(); $cab = (C 0 0 0) }
        'evil' { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 30 6 10))), 0, 30, $W, ($H - 30)); $cab = (C 0 0 0) }
        'knight' { $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 30, $W, ($H - 30)); $pg = New-Object System.Drawing.Pen((C 52 18 82), 1); for ($x = 0; $x -lt $W; $x += 24) { $g.DrawLine($pg, $x, 30, $x, $H) }; for ($y = 30; $y -lt $H; $y += 24) { $g.DrawLine($pg, 0, $y, $W, $y) }; $pg.Dispose(); $cab = (C 0 0 0) }
        'boneyard' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 70 78 92), (C 30 32 38), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $lp = New-Object System.Drawing.SolidBrush((ARGB 70 0 0 0)); foreach ($q in @(@(14, 150, 26, 50), @(176, 160, 30, 40))) { $g.FillRectangle($lp, $q[0], $q[1], $q[2], $q[3]) }; $lp.Dispose(); $cab = (C 22 23 28) }
        'corrupta' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 90 20 60), (C 20 6 20), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 10 4 10) }
        'niebla' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 74 28 124), (C 30 10 56), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 90 30 140) }
        'abismo' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 70 44), (C 18 34 22), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 78 56 40) }
        'pintor' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 212 212 212), (C 170 170 170), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 0 0 128) }
        'clima' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 106 122 168), (C 70 84 128), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 38 48 92) }
        'arana' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 14 34), (C 10 4 8), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); Vv-Red $g ($W / 2) 32 150 (ARGB 60 230 225 235) 9 10 170 5; $cab = (C 10 4 8) }
        'historia' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 120 86 40), (C 46 32 16), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $lom = New-Object System.Drawing.SolidBrush((ARGB 50 0 0 0)); for ($x = 6; $x -lt $W; $x += 22) { $g.FillRectangle($lom, $x, 34, 14, 108) }; $lom.Dispose(); $cab = (C 72 50 22) }
        'enfosi' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 120 180 240), (C 200 230 255), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 252 200 55) }
        'teto' { $ray = New-Object System.Drawing.Pen((C 252 232 236), 8); for ($x = -$H; $x -lt $W; $x += 26) { $g.DrawLine($ray, $x, 32, ($x + $H), ($H + 32)) }; $ray.Dispose(); $cab = (C 214 40 64) }
        'pizza' { $roja = New-Object System.Drawing.SolidBrush((ARGB 90 220 40 40)); for ($x = 0; $x -lt $W; $x += 28) { $g.FillRectangle($roja, $x, 30, 14, $H) }; for ($y = 30; $y -lt $H; $y += 28) { $g.FillRectangle($roja, 0, $y, $W, 14) }; $roja.Dispose(); $cab = (C 70 200 40) }
        'punk' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 252 206 160), (C 244 150 110), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 96 74 68) }
    }
    if ($cab) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($cab)), 0, 0, $W, 30) }
    $acento = if ($gk.Acento) { $gk.Acento } else { $gk.Borde }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($acento)), 0, 30, $W, 2)
    $nom = if ($gk.Titulo) { $gk.Titulo } else { $script:invNombre }
    $est = if ($gk.FuenteTitulo -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $g.DrawString($nom, (FntP($gk.FuenteTitulo, 12, $est)), (New-Object System.Drawing.SolidBrush($gk.TituloColor)), 8, 4)
    $g.DrawString('INVITADO', (FntP('Consolas', 7, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 200, 200, 200))), ($W - 62), 10)
    if (-not $script:invPb) {
        # c00lgui no tiene retrato: su nombre glitcheado
        $dx = if ($fx -gt 0) { $Rnd.Next(-6, 7) } else { 0 }
        $g.DrawString('c00lgui', (FntP('Arial Black', 26)), (New-Object System.Drawing.SolidBrush((C 90 0 0))), (24 + $dx + 3), 66)
        $g.DrawString('c00lgui', (FntP('Arial Black', 26)), [System.Drawing.Brushes]::Red, (24 + $dx), 63)
    }
    # efecto de entrada de cada invitado
    if ($fx -gt 0) {
        switch ($gk.Estilo) {
            'hacker' { for ($i = 0; $i -lt 4; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((C 255 0 0), (C 255 255 255), (C 0 255 255))[$Rnd.Next(3)])), $Rnd.Next(-40, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 200), $Rnd.Next(1, 5)) } }
            'tele' { $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int]($H / 2 - $fx * 6), $W, [int]($fx * 12)) }
            'mlg' { Dibujar-Hit $g ($W / 2) 90 ([Math]::Max(10, $fx * 3)); $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 18), 255, 255, 255))), 0, 0, $W, $H) }
            'oeste' { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 140 110 70))), ($W - 52), 52, 22, 22); $g.FillEllipse([System.Drawing.Brushes]::Black, ($W - 46), 58, 10, 10) }
            'gunsaw' { $y = (14 - $fx) * 16; $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 255, 255, 255))), 0, $y, $W, 10) }
            'mew' { $z = New-Object System.Drawing.Pen((C 200 40 35), 5); $z.StartCap = 'Round'; $z.EndCap = 'Round'; for ($i = 0; $i -lt 3; $i++) { $g.DrawLine($z, (40 + $i * 40), 40, (90 + $i * 40), 150) } }
            'web' { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 130 200))), 0, 32, [int]($W * (14 - $fx) / 14), 4) }
            'lobo' { if ($fx % 4 -lt 2) { $am = New-Object System.Drawing.Pen((C 255 170 40), 3); $g.DrawRectangle($am, 6, 34, ($W - 12), 112) } }
            'culto' { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 18), 200, 20, 30))), ($W / 2 - 30), (90 - $fx * 2), 60, ($fx * 4)) }
            'kaiju' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 16), 255, 160, 40))), 0, 0, $W, $H) }
            'pressure' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 16), 70, 190, 200))), 0, 0, $W, $H) }
            'dod' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 16), 200, 0, 0))), 0, 0, $W, $H) }
            'zorro' { for ($i = 0; $i -lt 3; $i++) { Dibujar-Corazon $g (50 + $i * 60) (150 - (14 - $fx) * 8) 10 ([Math]::Min(255, $fx * 18)) } }
            'femta' { for ($i = 0; $i -lt 4; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((C 230 20 40), (C 255 255 255), (C 40 230 255))[$Rnd.Next(3)])), $Rnd.Next(-40, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 200), $Rnd.Next(2, 6)) } }
            'pop' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 90, 230, 250))), 0, [int]((14 - $fx) * 15), $W, 10) }
            'gran' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 32, 208, 44))), 0, 0, $W, $H) }
            'evil' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 150, 0, 10))), 0, 0, $W, $H) }
            'knight' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(170, $fx * 12), 200, 0, 20))), 0, 0, $W, $H) }
            'boneyard' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(160, $fx * 11), 226, 128, 146))), [int]($W - (14 - $fx) * 18), 0, $W, $H) }
            'corrupta' { $rn = New-Object System.Random $fx; for ($i = 0; $i -lt 6; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((C 255 40 80), (C 90 230 255), (C 255 230 60))[$rn.Next(3)])), $rn.Next(0, $W), $rn.Next(30, $H), $rn.Next(10, 40), $rn.Next(4, 10)) } }
            'niebla' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(180, $fx * 12), 255, 186, 244))), 0, 0, $W, $H) }
            'abismo' { $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([Math]::Min(220, $fx * 16), 210, 255, 220), 2); for ($i = 0; $i -lt 6; $i++) { $xx = 20 + $i * 36; $g.DrawLine($p, $xx, ($H - (14 - $fx) * 14), ($xx + 6), ($H - (14 - $fx) * 14 - 40)) }; $p.Dispose() }
            'pintor' { $pl = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([Math]::Min(160, $fx * 11), 170, 120, 255), 1.4); for ($i = 0; $i -lt 6; $i++) { $yy = 34 + ((14 - $fx) * 14 + $i * 31) % 150; $g.DrawLine($pl, 0, $yy, $W, $yy) }; $pl.Dispose() }
            'clima' { $pl = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 235, 240, 255), 1.2); for ($i = 0; $i -lt 16; $i++) { $xx = 8 + $i * 15; $yy = 34 + ((14 - $fx) * 12 + $i * 23) % 120; $g.DrawLine($pl, $xx, $yy, ($xx - 3), ($yy + 12)) }; $pl.Dispose() }
            'arana' { Vv-Red $g 0 32 ((14 - $fx) * 22) ([System.Drawing.Color]::FromArgb([Math]::Min(220, $fx * 16), 240, 235, 240)) 6 0 90 4 }
            'historia' { $hj = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(220, $fx * 16), 250, 242, 222)); for ($i = 0; $i -lt 4; $i++) { $g.FillRectangle($hj, (24 + $i * 50), (34 + (14 - $fx) * 11 + ($i % 2) * 16), 14, 18) }; $hj.Dispose() }
            'enfosi' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 255, 214, 60))), 0, 0, $W, $H) }
            'teto' { for ($i = 0; $i -lt 3; $i++) { Texto-Contorno $g '♪' 'Segoe UI Symbol' 20 (40 + $i * 60) (130 - (14 - $fx) * 7) (@((C 214 40 64), (C 246 170 30), (C 255 255 255))[$i]) 3 ([Math]::Min(255, $fx * 18)) } }
            'pizza' { for ($i = 0; $i -lt 4; $i++) { Dibujar-Trozo $g (30 + $i * 52) (40 + (14 - $fx) * 9 + ($i % 2) * 14) 20 ($fx * 25 + $i * 70) } }
            'punk' { for ($i = 0; $i -lt 3; $i++) { Texto-Contorno $g (@('♪', '♫', '★')[$i]) 'Segoe UI Symbol' 22 (40 + $i * 60) (130 - (14 - $fx) * 7) (@((C 255 255 255), (C 255 80 160), (C 255 255 255))[$i]) 3 ([Math]::Min(255, $fx * 18)) } }
        }
    }
    $g.DrawRectangle((New-Object System.Drawing.Pen($acento, 3)), 1, 1, ($W - 3), ($H - 3))
}

$invTimer = New-Object System.Windows.Forms.Timer
$invTimer.Interval = 30
$invTimer.Add_Tick({
    Sin-Destellos
    $f = $script:inv
    if (-not $f -or $f.IsDisposed) { $invTimer.Stop(); return }
    if ($script:invSale) {
        $script:invAnim -= 1; Colocar-Invitado
        if ($script:invAnim -le 0) { Cerrar-Invitado }
        return
    }
    if ($script:invAnim -lt 10) { $script:invAnim++; Colocar-Invitado }
    if ($script:invPos -lt $script:invTexto.Length) { $script:invPos++; $script:invLbl.Text = $script:invTexto.Substring(0, $script:invPos) }
    if ($script:invEst -gt 0 -and $script:invPb) {
        $script:invEst--
        if (-not $script:invRuido) { $script:invRuido = Nuevo-Ruido 64 40 }
        if ($script:invEst -gt 0) { Llenar-Ruido $script:invRuido; $script:invPb.Image = $script:invRuido; $script:invPb.Invalidate() } else { $script:invPb.Image = $script:dImg }
    }
    if ($script:invFx -gt 0) { $script:invFx--; $f.Invalidate() }
})

function Cerrar-Invitado {
    $invTimer.Stop()
    if ($script:inv -and -not $script:inv.IsDisposed) { if ($script:invPb) { $script:invPb.Image = $null }; $script:inv.Close(); $script:inv.Dispose() }
    $script:inv = $null; $script:invPb = $null; $script:invLbl = $null; $script:invSkin = $null
    if ($script:dImg) { $script:dImg.Dispose(); $script:dImg = $null }
    if ($script:invRuido) { $script:invRuido.Dispose(); $script:invRuido = $null }
}

# efectos según lo que se dice en la discusión
function Efectos-Linea($quien, $txt) {
    if ($quien -eq 'Nanachi' -and $txt -match 'Nnaa') { Sonido-De 'Nanachi' 'brillo' }
    if ($txt -match '[Ee]stofado') { Sonido-De 'Nanachi' 'burbujas' }
    if ($quien -eq 'Velvet' -and $txt -match '[Tt]elaraña|[Ee]scupe') { Sonido-De 'Velvet' 'escupe' }
    if ($quien -eq 'Malkuth') { if ($txt -match 'aiiire|suéltalo|[Rr]espira') { Sonido-De 'Malkuth' 'respira' } elseif ($txt -match '[Uu]oh') { Sonido-De 'Malkuth' 'tropiezo' } elseif ($txt -match '[Ll]ibro') { Sonido-De 'Malkuth' 'pagina' } }
    if ($txt -match 'STALL') { Sonido-De 'Evil Scary' 'stall' }
    elseif ($txt -match 'EVIL AND SCARY') { Sonido-De 'Evil Scary' 'susto' }
    if ($txt -match 'FSSS|niebla rosa') { Sonido-De 'Soft Fuzzy Man' 'puff' }
    if ($txt -match 'RUGE|ROAAA') { Sonido-De 'Roaring Knight' 'rugido' } elseif ($txt -match 'Black Knife') { Sonido-De 'Roaring Knight' 'tajo' }
    $esInv = $quien -ne $script:skinNombre
    $f = if ($esInv) { $script:inv } else { $form }
    if ($txt -match 'BANG') { Sonido-De 'Zodiac' 'bang'; Sacudir $form 10; Sacudir $script:inv 10; if ($esInv) { $script:invFx = 8 } }
    elseif ($txt -match 'Smokebomb') { Sonido-De 'Mikaela' 'humo'; Humo $f }
    elseif ($txt -match "DON'T TOUCH|NO TOQUES|motosierra") { Sonido-De 'Kevin' $(if ($txt -match 'motosierra') { 'grito' } else { 'grr' }); Sacudir $f 9 }
    elseif ($quien -eq 'Kevin' -and $txt -match 'ÑAM') { Sonido-De 'Kevin' 'nam' }
    elseif ($txt -match 'KABOOM|EXPLOTA|explota') { Sonido-De 'Kennyoung' 'kaboom'; Sacudir $form 12; Sacudir $script:inv 12 }
    elseif ($txt -match 'ENCORE|público') { Sonido-De 'Kennyoung' 'publico' }
    elseif ($txt -match 'Rasguea|acorde|guitarra') { Sonido-De 'Kennyoung' 'acorde' }
    elseif ($txt -match 'ÑAM|CHOMP|[Ee]ructa|[Tt]raga') { Sonido-De 'Guillotina' 'comer'; Sacudir $f 6 }
    elseif ($txt -match 'Bzz') { if ($esInv) { $script:invEst = 12 } else { Corte-Senal 8 } }
    elseif ($txt -match 'GRRRRRAAAARRRGH|AAARGH') { Sonido-De 'Pyrophina y Zaratana' 'pruge'; Sacudir $form 8; Sacudir $script:inv 8 }
    elseif ($txt -match 'GRRRR, GRRRRR|Grrrr, burp') { Sonido-De 'Pyrophina y Zaratana' 'zruge'; Sacudir $f 6 }
    elseif ($txt -match 'AAAAAAAAH|GRITA') { Sonido-De 'Cordero y Cabra' 'grito'; Sacudir $f 8 }
    elseif ($txt -match 'Beee') { Sonido-De 'Cordero y Cabra' 'balido' }
    elseif ($txt -match 'NO TE MUEVAS|GRRGH|FURIOSA|denegada') { Sacudir $f 8 }
    if ($quien -eq 'Averi' -and $Rnd.Next(2) -eq 0) { Sonido-De 'Averi' 'yip' }
    if ($quien -eq 'Kasane Teto') { Voz-Teto $txt }
    if ($quien -eq 'Pursuer') { if ($txt -match 'CARNE|AÚLLA') { Sonido-De 'Pursuer' 'aullido'; Sacudir $f 10 } elseif ($txt -match 'te veo|Desaparece') { Sonido-De 'Pursuer' 'acecho' } }
    if ($quien -eq 'Mikaela' -and $txt -match 'mira') { Sonido-De 'Mikaela' 'apuntar' }
    if ($quien -eq 'Guillotina' -and $txt -match 'boca') { Sonido-De 'Guillotina' 'golpe' }
    if ($quien -eq 'Static Miku' -and $esInv) { $script:invFx = 6 }
    if ($quien -eq 'c00lgui' -and $esInv) { $script:invFx = 8 }
    # Kevin en su Paint pone cara según lo que dice
    if ($quien -eq 'Kevin' -and -not $esInv) {
        if ($txt -match 'motosierra') { Actor-Pose 'V' 'motosierra' 1800 }
        elseif ($txt -match 'MUERDO|BITE|muerde') { Actor-Pose 'V' 'muerde' 2400 }
        elseif ($txt -match "DON'T TOUCH|NO TOQUES|cuchillo") { Actor-Pose 'V' 'arma' 2200 }
        elseif ($txt -match 'mermelada|jelly') { Actor-Pose 'V' 'mermelada' 2400 }
        elseif ($txt -match 'queso azul|huele') { Actor-Pose 'V' 'sudor' 2200 }
        elseif ($txt -match 'baila|canta|♪') { Actor-Pose 'V' 'baile' 3000 }
    }
}

# la frase del invitado siempre cabe: si es larga, la letra se hace un poco más pequeña
function Encajar-Invitado($txt) {
    $l = $script:invLbl; if (-not $l) { return }
    if (-not $script:invTamBase) { $script:invTamBase = $l.Font.Size }
    $fam = $l.Font.FontFamily; $st = $l.Font.Style; $tam = $script:invTamBase
    while ($tam -gt 6) {
        $fn = New-Object System.Drawing.Font($fam, [float]$tam, $st, [System.Drawing.GraphicsUnit]::Pixel)
        $h = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $fn, (New-Object System.Drawing.Size(($l.ClientSize.Width - $l.Padding.Horizontal), 100000)), [System.Windows.Forms.TextFormatFlags]::WordBreak).Height
        if ($h -le ($l.ClientSize.Height - $l.Padding.Vertical)) { break }
        $fn.Dispose(); $tam -= 1
    }
    $l.Font = New-Object System.Drawing.Font($fam, [float]$tam, $st, [System.Drawing.GraphicsUnit]::Pixel)
}
function Iniciar-Discusion {
    if (-not $script:aj.Invitados) { return }
    if ($script:discutiendo -or (Ocupado) -or $form.WindowState -eq 'Minimized') { return }
    # la ventanita de la anterior todavía se está yendo, o acaba de terminar
    if ($script:inv -or ([Environment]::TickCount - $script:dFin) -lt 2500) { return }
    if ([Environment]::TickCount -lt $script:twBloqueo) { return }
    $yo = $script:skinNombre
    # las skins archivadas no tienen charlas: ni cuando están puestas ni como invitadas
    if (Es-Archivada $yo) { return }
    $cands = @($Discusiones | Where-Object { $q = @($_ | ForEach-Object { $_[0] }); ($q -contains $yo) -and -not @($q | Where-Object { Es-Archivada $_ }).Count })
    if ($cands.Count -eq 0) { return }
    # no repetir la misma conversación dos veces seguidas
    if ($cands.Count -gt 1) { $cands = @($cands | Where-Object { -not [object]::ReferenceEquals($_, $script:dUltima) }) }
    $script:dLineas = $cands[$Rnd.Next($cands.Count)]; $script:dUltima = $script:dLineas
    $invitado = @($script:dLineas | ForEach-Object { $_[0] } | Where-Object { $_ -ne $yo })[0]
    $script:dImg = Cargar-Img $Skins[$invitado].Gif
    $script:dIdx = 0; $script:discutiendo = $true
    Abrir-Invitado $invitado
    $dTimer.Interval = 450; $dTimer.Start()
}

function Paso-Discusion {
    $dTimer.Stop()
    if (-not $script:discutiendo) { return }
    if ($script:dIdx -ge $script:dLineas.Count) { Fin-Discusion; return }
    $l = $script:dLineas[$script:dIdx]; $script:dIdx++
    $quien = $l[0]; $txt = $l[1]
    if ($quien -ne $script:skinNombre) {
        # habla el invitado, en su ventanita
        $script:invTexto = $txt; $script:invPos = 0; Encajar-Invitado $txt
        switch ($script:skin.Estilo) {
            'lobo' { Ag-Cara 'molesta' 2500 }
            'zorro' { $script:caraModo = 'abiertos' }
            'culto' { if ($Rnd.Next(2) -eq 0) { Cara2 'risa' 1600 } }
            'pizza' { if ($Rnd.Next(2) -eq 0) { Cara (Azar @('piensa', 'chulo', 'sudor')) 1800 } }
            { $_ -in @('mew', 'mlg', 'tele', 'oeste') } { if ($Rnd.Next(2) -eq 0) { Cara 'clic' 1600 } }
        }
    } else {
        if ($script:skin.Estilo -eq 'hacker') { Glitch 3 "> $txt" } else { Decir-Fijo $txt 'abiertos' 0 }
    }
    Efectos-Linea $quien $txt
    $dTimer.Interval = [Math]::Max(2400, 1500 + $txt.Length * 55)
    $dTimer.Start()
}

function Fin-Discusion($rapido = $false) {
    $dTimer.Stop()
    $eraDiscusion = $script:discutiendo
    $script:discutiendo = $false; $script:dInvitadoHabla = $false; $script:dFin = [Environment]::TickCount
    if ($rapido) { Cerrar-Invitado; return }
    if ($script:inv) { $script:invSale = $true; $invTimer.Start() }
    # a veces el anfitrión remata con su opinión del invitado
    if ($eraDiscusion -and $script:invNombre -and $Rnd.Next(2) -eq 0) { Decir (Opinion $script:invNombre) 'abiertos' }
}

# frases cuando no haces nada
$idleTimer = New-Object System.Windows.Forms.Timer
$idleTimer.Interval = 18000
$idleTimer.Add_Tick({
    if ((Ocupado) -or $script:modoSkins -or $script:discutiendo) { return }
    $k = $script:skin; $r = $Rnd.Next(100)
    if ($r -lt 20) { Decir (Opinion-Azar) 'abiertos'; return }   # opina de otra skin
    if ($r -lt 38) { Iniciar-Discusion; return }                 # discute con otro asistente
    switch ($k.Estilo) {
        'hacker' { if ($r -lt 50) { Glitch 6 (Azar $k.Idle) } else { Decir (Azar $k.Idle) } }
        'tele' {
            if ($r -lt 32 -and $script:imgs.raro) { Cara 'raro' 3500; Decir (Azar $k.Raro) }
            elseif ($r -lt 55) { Corte-Senal 8; Decir (Azar $k.Idle) }
            else { Decir (Azar $k.Idle) }
        }
        'mew' {
            if ($r -lt 50 -and $script:gVivo) { Guillotina-Ataque (Azar @('lanza', 'digiere', 'come')) (Azar $k.Idle) }
            elseif ($r -lt 62 -and $script:gVivo -and $script:gFase2) { Guillotina-Ataque 'barriga' '*Se golpea la barriga. Tiembla todo el callejón.*' }
            else { Decir (Azar $k.Idle) }
        }
        'mlg' {
            if ($r -lt 40) { Sonido 'humo'; $form.Opacity = 0.35; $humoTimer.Start(); Decir '*Smokebomb.* Ahora no me ves.' }
            elseif ($r -lt 52) { Cara 'clic' 2500; Decir '¡¿Un Terminator?! ...falsa alarma.' }
            else { Decir (Azar $k.Idle) }
        }
        'gunsaw' {
            if ($k.Telarana -and $r -lt 50 -and -not $script:telarana) { $presa = Velvet-Escupir; if ($presa) { Decir "*Escupe una telaraña sobre $presa.* Uy. Se me escapó, cielo." } }
            elseif ($k.Hambre -and $r -lt 50) { Decir 'BLUB. BLUB. *Dune hace burbujas.*' }
            else { Decir (Azar $k.Idle) }
        }
        'oeste' {
            if ($r -lt 40 -and $script:balas -gt 0) { [void](Zodiac-Disparo); Decir '¡Algo se ha movido! *BANG* ...era una mosca.' }
            elseif ($r -lt 52) { Cara 'pose' 3000; Decir '*Posa para nadie en concreto.*' }
            else { Decir (Azar $k.Idle) }
        }
        'culto' {
            if ($r -lt 55) { Sonido 'balido'; Cara 'clic' 1800; Decir (Azar $k.Idle) }
            elseif ($r -lt 65) { Sonido 'risa'; Cara2 'risa' 2600; Decir 'Cabra: *Se ríe sola mirando al Cordero.* Nada, nada.' }
            else { Decir (Azar $k.Idle) }
        }
        'kaiju' {
            if ($r -lt 70) { Kaiju-Ataque (@('P', 'Z')[$Rnd.Next(2)]) }
            elseif ($r -lt 80) { if ($Rnd.Next(2) -eq 0) { Sonido 'pruge'; Decir 'Pyrophina: ¡GRRRRRAAAARRRGH!' } else { Sonido 'zruge'; Decir 'Zaratana: ¡GRRRR, GRRRRR!' } }
            else { Decir (Azar $k.Idle) }
        }
        'pressure' {
            if ($r -lt 52 -and -not $script:modoTienda) { Decir (Azar $k.Respiradero) }
            elseif ($r -lt 60) { Decir 'Ese parecía un poco distinto de lo normal. Hmm. Me pregunto qué le pasa.' }
            else { Decir (Azar $k.Idle) }
        }
        'dod' {
            if ($r -lt 52) { Pursuer-Acecho }
            elseif ($r -lt 62) { Pursuer-Ataque 'aullido' }
            else { Decir (Azar $k.Idle) }
        }
        'femta' {
            if ($r -lt 25) { Token-Palabra; Sonido 'glitch'; Decir (Azar $k.Idle) }
            elseif ($r -lt 35) { Sonido 'golpe'; $a = $script:actores['K']; if ($a) { $a.Temblor = 8 }; Decir '*Le pega un cabezazo al altavoz. Suena más fuerte.* Mejor.' }
            else { Decir (Azar $k.Idle) }
        }
        'pop' {
            if ($r -lt 30 -and -not $script:popDND) { [void](Tetra-Mensaje); Decir (Azar @('*Le llega un mensaje. Lo mira. Lo deja en visto.* Luego contesto.', '*Mira el móvil.* Es neems. ...le contesto mañana.', '*Ping.* Uy. Un mensaje. Qué miedo dan los mensajes.')) }
            elseif ($r -lt 45) { Sonido 'disco'; $script:popBaila = 90; Decir '*Baila un poco de disco sin levantarse mucho del sitio.*' }
            else { Decir (Azar $k.Idle) }
        }
        'enfosi' {
            if ($script:ef -and -not $script:ef.W -and -not $script:ef.Cartel -and $r -lt 40) { Enfosi-Llega }
            elseif (-not $script:ef -or -not $script:ef.W) { Decir (Azar $k.Idle) }
        }
        'teto' {
            if ($r -lt 18) { Teto-Pajaro; Decir '¡Mira, un pajarito! ...¿de dónde salen todos?' }
            elseif ($r -lt 32) { Sonido (Azar @('hi', 'hehe', 'huh')); $script:tetoVozT = [Environment]::TickCount; Decir (Azar $k.Idle) }
            elseif ($r -lt 50) {
                Sonido 'canta'; $script:tetoVozT = [Environment]::TickCount
                $a = $script:actores['T']; if ($a) { $a.Salto = 12 }
                foreach ($i in 0..3) { Flotante (Azar @('♪', '♫')) (480 + $i * 34) (80 + $Rnd.Next(60)) (@((C 214 40 64), (C 246 170 30), (C 255 255 255), (C 214 40 64))[$i]) 22 'Segoe UI Symbol' }
                Decir (Azar @('♪ La la la~ ♪ *Canta sola en medio del escritorio.*', '♪ Lu lu lu~ ♪ Me la acabo de inventar. ¡Ya se me ha olvidado!', '♪ Na na na~ ♪ *Baila y canta a la vez. Casi se cae.*', '♪ Du du du~ ♪ ¿Te gusta? ¡Es mi nuevo single!'))
            }
            else { Decir (Azar $k.Idle) }
        }
        'gran' {
            if ($r -lt 55) { Gran-Tapar 6000; Decir (Azar $k.Idle) }
            else { Decir (Azar $k.Idle) }
        }
        'evil' {
            if ($r -lt 40) { Decir (Azar $k.Idle) }
            elseif ($r -lt 55) { Es-Reset; Es-Rebote 3.0; Decir '*Bota sin avisar.* ...el sonido ha sido más agudo esta vez.' }
            else { Decir (Azar $k.Idle) }
        }
        'boneyard' {
            $d = $script:dy
            if (-not $d -or $d.Estado -ne 'vivo') { Decir (Azar $k.Idle) }
            elseif ($r -lt 50) { Actor-Pose 'D' 'flip' 800; Sonido 'flip'; Decir (Azar $k.Idle) }
            elseif ($r -lt 60) { Actor-Pose 'D' 'lame' 1840; Sonido 'lame'; Decir (Azar $k.Lame) }
            elseif ($r -lt 66) { Dy-Wisps }
            else { Decir (Azar $k.Idle) }
        }
        'corrupta' {
            $e = $script:el
            if ($e -and $e.Glitch) { }
            elseif ($r -lt 52) { El-Teleport; Decir (Azar $k.Teleport) }
            elseif ($r -lt 60) { $a = $script:actores['E']; if ($a) { $a.Alfa = 0.25 }; if ($e) { $e.InvHasta = [Environment]::TickCount + $ElTiempos.Invisible }; Decir (Azar $k.Invisible) }
            elseif ($e -and $e.Rabia -ge 50) { Decir (Azar $k.Silencio) }
            else { Decir (Azar $k.Idle) }
        }
        'knight' {
            if ($r -lt 30) { Actor-Pose 'K' 'risa' 2500; Decir (Azar $k.Idle) }
            elseif ($r -lt 42) { Actor-Pose 'K' 'tajo' 800; Sonido 'tajo'; Decir '* El Knight corta el aire. * Solo para que lo oigas.' }
            else { Decir (Azar $k.Idle) }
        }
        'niebla' {
            if ($r -lt 30) { Actor-Pose 'F' 'brazos' 2200; Decir (Azar $k.Idle) }
            elseif ($r -lt 42) { Sonido 'puff'; Sf-Niebla 1500 90; Decir '*Suelta una nubecita rosa.* Perdona. Es que me emociono.' }
            else { Decir (Azar $k.Idle) }
        }
        'abismo' {
            if ($r -lt 30) { Nn-Cara 'sentado' 6000; Decir (Azar $k.Idle) }
            elseif ($r -lt 42) { Sonido 'burbujas'; Nn-Reset; $script:nn.Vapor = 40; Nn-Cara 'mastica' 3000; Decir (Azar @('*Remueve la olla.* Glup. Glup. Eso es buena señal. Creo.', '*Prueba el estofado con una cuchara larga.* ...le falta algo. Le faltan muchas cosas.', 'Si oyes burbujas, es el estofado. Si oyes otra cosa, no es el estofado. Corre.')) }
            elseif ($r -lt 52) { Nn-Cara 'triste' 5000; Decir (Azar @('*Mira el muñeco de pájaro un buen rato.* ...lo cosí yo. Para alguien que quería mucho.', 'Mitty decía que todo vuelve al Abismo. Yo no me lo creo del todo. Pero me gusta pensarlo.', 'Algún día cocinaré algo rico de verdad. Por si nos volvemos a ver. Nnaa.')) }
            elseif ($r -lt 62) { Nn-Cara 'risa' 4000; Decir (Azar @('*Se ríe sola de algo.* Me he acordado de Reg cuando probó mi estofado. Puso una cara...', 'Riko se quedó dormida encima de un libro de setas. Igual que yo. Somos unos sabios.')) }
            elseif ($r -lt 70) { Nn-Cara 'nnaa' 2000; Sonido 'silbato'; Decir (Azar @('¿Has oído eso? Un silbato. Hay exploradores cerca. Me escondo. *No se esconde.*', '¡Nnaa! *Da un respingo.* ...era una seta cayéndose. Nada.')) }
            else { Decir (Azar $k.Idle) }
        }
        'pintor' {
            $e = $script:pr
            if ((Pr-Mina-Activa) -or (Pr-Voz-Suena)) { }
            elseif ($e -and $e.Calor -ge 70) { Pr-Cara 'susto' 3500; if ($Rnd.Next(2) -eq 0 -or -not (Pr-Voz 'calor')) { Decir (Azar $k.Calentando) } }
            elseif ($r -lt 32) { $cn = Azar @('feliz', 'triste', 'enfado', 'neutra'); Pr-Cara $cn 4500; Decir (Azar $k[('Dibuja' + $cn.Substring(0, 1).ToUpper() + $cn.Substring(1))]) }
            elseif ($e -and $e.Paisaje -ge 1 -and $r -lt 56) { Decir (Azar $k.PaisajeIdle) }
            elseif ($r -lt 72) { Decir (Azar $k.Paisajes) }
            else { if (-not (Pr-Voz 'idle')) { Decir (Azar $k.Idle) } }
        }
        'clima' {
            $e = $script:wg; $cl = Wg-Cielo
            if (Wg-Llora) { Decir (Azar $k.LloraIdle) }
            elseif ($r -lt 26) { Wg-Parte }
            elseif ($r -lt 36) { Wg-Manana }
            elseif ($e -and (Wg-Paraguas-Visible) -and $r -lt 50) { Decir (Azar $k.SinParaguas) }
            elseif ($e -and $e.Palabras -ge 3 -and $r -lt 62) { Decir (Azar $k.Palabras) }
            elseif ($cl -eq 'vivos') { Decir (Azar $k.VivosIdle) }
            elseif ($r -lt 74) { if (Wg-Noche) { Decir (Azar $k.IdleNoche) } else { Decir (Azar $k[('Idle' + $cl.Substring(0, 1).ToUpper() + $cl.Substring(1))]) } }
            else { Decir (Azar $k.Idle) }
        }
        'arana' {
            $e = $script:vv
            if ($e -and $e.TrampaT -gt 0) { }
            elseif ($r -lt 52) { $p = Vv-Escupir; if ($p) { Decir ((Azar $k.Escupe) -f $p) } else { Decir (Azar $k.Idle) } }
            elseif ($e -and $e.Hambre -ge 70 -and $r -lt 76) { Sonido 'siseo'; Decir (Azar $k.Hambrienta) }
            else { Decir (Azar $k.Idle) }
        }
        'lobo' {
            $e = $script:ag
            if ($e -and ($e.Brecha -or $e.Completa -or $e.FiltroT -gt 0)) { }
            elseif ($r -lt 44 -and (Ag-Filtro)) { }
            elseif ($r -lt 58) { Ag-Cara 'sonrie' 3000; Decir (Azar $k.Idle) }
            elseif ($r -lt 66) { Ag-Cara 'abiertos' 3500; Decir (Azar $k.IdleOjos) }
            else { Decir (Azar $k.Idle) }
        }
        'historia' {
            $e = $script:mk
            if ($e -and $e.Respira -gt 0) { }
            elseif ($e -and $e.Hundida) { Decir (Azar $k.HundidaIdle) }
            elseif ($r -lt 30) { Mk-Cara 'decidida' 4000; Decir (Azar $k.Idle) }
            elseif ($r -lt 40) { Actor-Pose 'M' 'tropiezo' 1500; Sonido 'tropiezo'; Decir (Azar $k.Tropiezo) }
            elseif ($r -lt 54) { Mk-Cara 'feliz' 4000; Decir (Azar $k.Aficiones) }
            elseif ($r -lt 62) { Mk-Cara 'sombria' 4500; Decir (Azar $k.Recuerdos) }
            else { Decir (Azar $k.Idle) }
        }
        'punk' {
            $e = $script:ky
            if ($e -and $r -lt 60) { Decir (Azar $k[('Idle' + $e.Escena.Substring(0, 1).ToUpper() + $e.Escena.Substring(1))]) }
            else { Decir (Azar $k.Idle) }
        }
        'pizza' {
            if ($r -lt 52 -and -not $script:pzQueso -and $script:pzFx -le 0) { if (-not (Kevin-Queso)) { Decir (Azar $k.Idle) } }
            elseif ($r -lt 62) { Actor-Pose 'V' 'mermelada' 2700; Decir (Azar @('*Saca un bote de mermelada.* Esta tampoco se toca. Ni la pizza ni la mermelada.', '*Abraza su mermelada.* Don''t touch my jelly. Es la regla número tres.', 'Mermelada de fresa. Mía. Como todo lo que está en este Paint.')) }
            elseif ($r -lt 70) { Actor-Pose 'V' 'piensa' 2600; Decir (Azar $k.Idle) }
            elseif ($r -lt 76) { Sonido 'baile'; Actor-Pose 'V' 'baile' 4300; Decir '*Se pone a bailar solo.* ¡Nadie me mira! ...tú me miras. Da igual.' }
            else { Decir (Azar $k.Idle) }
        }
        'zorro' {
            if ($r -lt 60 -and $script:antojo -ge 60) { Decir '¿...huele a pollo? No huele. Pero me apetece un sándwich. (haz clic en mí)' 'serio' }
            elseif ($r -lt 70) { Sonido 'yip'; Decir (Azar $k.Idle) 'abiertos' }
            else { Decir (Azar $k.Idle) (@('cerrados', 'abiertos')[$Rnd.Next(2)]) }
        }
        default { Decir (Azar $k.Idle) }
    }
})

# ================= GLITCH (c00lgui) =================
$CharsGlitch = '#@$%&!?01/\|<>{}[]~^*=+'.ToCharArray()
$ErroresGlitch = @(
    'FATAL ERROR 0x0000C00L'
    'MEMORY CORRUPTED AT 0xDEADBEEF'
    'gui.exe has stopped responding'
    'T E A M   C 0 0 L K I D D'
    'ERR: reality.dll not found'
    '!!!! SYSTEM COMPROMISED !!!!'
    'stack overflow // stack overflow //'
)
function Revolver([string]$t) {
    $a = $t.ToCharArray()
    for ($i = 0; $i -lt $a.Length; $i++) { if ($Rnd.Next(100) -lt 40) { $a[$i] = $CharsGlitch[$Rnd.Next($CharsGlitch.Length)] } }
    return -join $a
}

$script:gTicks = 0; $script:gAccion = $null; $script:gOrig = @(); $script:gBase = $null
$gTimer = New-Object System.Windows.Forms.Timer
$gTimer.Interval = 45
$gTimer.Add_Tick({
    if ($script:gTicks -le 0) {
        $gTimer.Stop()
        foreach ($o in $script:gOrig) { $o.C.Text = $o.T }
        $form.BackColor = $script:skin.Fondo
        $form.Opacity = (Opacidad-Base)
        $form.Location = $script:gBase
        $script:glitching = $false
        $form.Invalidate()
        $acc = $script:gAccion; $script:gAccion = $null
        if ($acc -is [hashtable]) {
            $script:skinNombre = $acc.Skin; Construir-UI
            Glitch 16 (Mensaje-Entrada $acc.Prev)
        } elseif ($acc) { Decir $acc }
        return
    }
    $script:gTicks--
    $colores = @((C 0 0 0), (C 120 0 0), (C 255 0 0), (C 20 0 0), $script:skin.Fondo)
    $form.BackColor = $colores[$Rnd.Next($colores.Count)]
    $form.Opacity = 0.55 + $Rnd.NextDouble() * 0.45
    $form.Location = New-Object System.Drawing.Point(($script:gBase.X + $Rnd.Next(-9, 10)), ($script:gBase.Y + $Rnd.Next(-6, 7)))
    foreach ($o in $script:gOrig) { if ($Rnd.Next(2) -eq 0) { $o.C.Text = Revolver $o.T } else { $o.C.Text = $o.T } }
    if ($script:status) { $script:status.Text = $ErroresGlitch[$Rnd.Next($ErroresGlitch.Count)] }
    $form.Invalidate()
})

function Glitch($ticks, $accion) {
    if ($script:glitching) { return }
    $script:glitching = $true
    # modo seguro: el glitch no parpadea; se salta directamente a lo que tenía que pasar después
    $script:gTicks = $(if ($script:aj.Epilepsia) { 0 } else { $ticks }); $script:gAccion = $accion; $script:gBase = $form.Location
    $script:gOrig = @()
    $todos = @($form.Controls) + @($script:grid.Controls)
    foreach ($c in $todos) {
        if ($c -ne $script:status -and $c -ne $script:urlLbl -and $c.Text) { $script:gOrig += @{ C = $c; T = $c.Text } }
    }
    try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Hand.Play() } } catch {}
    $gTimer.Start()
}

# ================= TRANSICIÓN: CARGAR PÁGINA WEB (SeaDrive) =================
$script:wPaso = 0; $script:wProg = 0
$wTimer = New-Object System.Windows.Forms.Timer
$wTimer.Interval = 40
$wTimer.Add_Tick({
    $script:wPaso++; $p = $script:wPaso
    $url = $script:skin.Url
    $script:urlLbl.Text = $url.Substring(0, [Math]::Min($url.Length, $p * 2))
    if ($p -gt 16) {
        $paso = $Rnd.Next(0, 7)
        if ($script:wProg -gt 60 -and $script:wProg -lt 72) { $paso = $Rnd.Next(0, 2) }   # se "atasca" un poco, como las webs de verdad
        $script:wProg = [Math]::Min(100, $script:wProg + $paso)
    }
    $script:wBar.Width = [int](3 * $script:wProg * $script:K)
    $spin = '◐◓◑◒'[$p % 4]
    if ($p -le 16) { $etapa = 'Conectando con seadrive.howto...' }
    elseif ($script:wProg -lt 30) { $etapa = 'Descargando seadrive.gif (37 KB)...' }
    elseif ($script:wProg -lt 60) { $etapa = 'Cargando sarcasmo.js...' }
    elseif ($script:wProg -lt 85) { $etapa = 'Aplicando estilos.css...' }
    else { $etapa = 'Casi listo... (mentira)' }
    $script:wMsg.Text = "$spin  $etapa"
    if ($script:wProg -ge 100) {
        $script:wFin++
        if ($script:wFin -gt 6) {
            $wTimer.Stop()
            $form.Controls.Remove($script:wOv); $script:wOv.Dispose()
            $script:urlLbl.Text = $url
            $script:transicion = $false
            Decir $script:wFinal
        }
    }
})

function Transicion-Web($final) {
    $script:transicion = $true
    $W = [int]($form.ClientSize.Width / $script:K); $H = [int]($form.ClientSize.Height / $script:K)
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(3, 89)
    $ov.Size = New-Object System.Drawing.Size(($W - 6), ($H - 89 - 11))
    $ov.BackColor = [System.Drawing.Color]::White
    $ow = $ov.Width

    $t1 = New-Object System.Windows.Forms.Label
    $t1.Text = 'seadrive.howto'
    $t1.Font = Fnt('Segoe UI Light', 22)
    $t1.ForeColor = (C 40 130 200)
    $t1.TextAlign = 'MiddleCenter'
    $t1.Location = New-Object System.Drawing.Point(0, 30)
    $t1.Size = New-Object System.Drawing.Size($ow, 50)

    $script:wMsg = New-Object System.Windows.Forms.Label
    $wMsg.Font = Fnt('Segoe UI Symbol', 9)
    $wMsg.ForeColor = (C 110 110 110)
    $wMsg.TextAlign = 'MiddleCenter'
    $wMsg.Location = New-Object System.Drawing.Point(0, 90)
    $wMsg.Size = New-Object System.Drawing.Size($ow, 24)

    $barO = New-Object System.Windows.Forms.Panel
    $barO.BackColor = (C 222 230 238)
    $barO.Location = New-Object System.Drawing.Point([int](($ow - 300) / 2), 122)
    $barO.Size = New-Object System.Drawing.Size(300, 12)
    $script:wBar = New-Object System.Windows.Forms.Panel
    $wBar.BackColor = (C 40 130 200)
    $wBar.Location = New-Object System.Drawing.Point(0, 0)
    $wBar.Size = New-Object System.Drawing.Size(0, 12)
    $barO.Controls.Add($wBar)

    $pie = New-Object System.Windows.Forms.Label
    $pie.Text = '© HowTo Corp.  ·  Tu asistente favorito (no tienes otro)'
    $pie.Font = Fnt('Segoe UI', 8)
    $pie.ForeColor = (C 160 160 160)
    $pie.TextAlign = 'MiddleCenter'
    $pie.Location = New-Object System.Drawing.Point(0, ($ov.Height - 26))
    $pie.Size = New-Object System.Drawing.Size($ow, 20)

    $ov.Controls.AddRange(@($t1, $wMsg, $barO, $pie))
    Escalar $ov
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:urlLbl.Text = ''
    $script:wOv = $ov; $script:wPaso = 0; $script:wProg = 0; $script:wFin = 0; $script:wFinal = $final
    $wTimer.Start()
}

# ================= TRANSICIÓN: ESTÁTICA DE TELE (Static Miku) =================
$script:sPaso = 0
$sTimer = New-Object System.Windows.Forms.Timer
$sTimer.Interval = 45
$sTimer.Add_Tick({
    $script:sPaso++
    Llenar-Ruido $script:sRuido
    $ov = $script:sOv
    if ($script:sPaso -gt 24) {
        # la tele "se enciende" desde una línea en el centro
        $W = $ov.Width; $H = $ov.Height
        $banda = [int]($H * ($script:sPaso - 24) / 8)
        $reg = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
        $reg.Exclude((New-Object System.Drawing.Rectangle(0, [int](($H - $banda) / 2), $W, $banda)))
        $viejo = $ov.Region; $ov.Region = $reg; if ($viejo) { $viejo.Dispose() }
    }
    if ($script:sPaso -ge 33) {
        $sTimer.Stop()
        $form.Controls.Remove($ov); $ov.Dispose(); $script:sRuido.Dispose()
        $script:transicion = $false
        Decir $script:sFinal
        return
    }
    $ov.Invalidate()
})

function Transicion-Estatica($final) {
    $script:transicion = $true
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0)
    $ov.Size = $form.ClientSize
    $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $script:sRuido = Nuevo-Ruido 120 64
    $ov.Add_Paint({
        $g = $_.Graphics; $g.ScaleTransform($script:K, $script:K)
        $W = [int]($this.Width / $script:K); $H = [int]($this.Height / $script:K)
        $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
        $g.DrawImage($script:sRuido, (New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
        if ($script:sPaso % 10 -lt 7) {
            $g.DrawString('CH 03', (FntP('Consolas', 20, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Lime, ($W - 120), 12)
        }
        $g.DrawString('▶ STATIC', (FntP('Consolas', 13, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 14, ($H - 36))
        if ($script:sPaso -gt 24) {
            $banda = [int]($H * ($script:sPaso - 24) / 8)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int](($H - $banda) / 2) - 3, $W, 3)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int](($H + $banda) / 2), $W, 3)
        }
    })
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:sOv = $ov; $script:sPaso = 0; $script:sFinal = $final
    try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Asterisk.Play() } } catch {}
    $sTimer.Start()
}

# ================= INTROS A PANTALLA COMPLETA (Guillotina y Angela) =================
$script:iPaso = 0; $script:iTotal = 0; $script:iRecursos = @()
$iTimer = New-Object System.Windows.Forms.Timer
$iTimer.Interval = 45
$iTimer.Add_Tick({
    $script:iPaso++
    if ($script:iPaso -ge $script:iTotal) {
        $iTimer.Stop()
        $form.Controls.Remove($script:iOv); $script:iOv.Dispose()
        foreach ($r in $script:iRecursos) { if ($r) { $r.Dispose() } }
        $script:iRecursos = @()
        $script:transicion = $false
        if ($script:iDespues) { $d = $script:iDespues; $script:iDespues = $null; & $d } else { Decir $script:iFinal 'abiertos' }
        return
    }
    # si la ventana cambia de tamaño durante la intro, la intro la sigue
    if ($script:iOv.Top -eq 0 -and ($script:iOv.Width -ne $form.ClientSize.Width -or $script:iOv.Height -ne $form.ClientSize.Height)) { $script:iOv.Size = $form.ClientSize }
    if ($script:iTick) { & $script:iTick $script:iOv $script:iPaso }
    $script:iOv.Invalidate()
})

# --- logo de inicio: JOSEPABLINI CORPORATION ---
$script:iDespues = $null
# los dos van de busto (cabeza y hombros); Tung Tung Sahur un poco más alto que el panda
$AltoTung = 1.08
function Logo-Inicio {
    $script:lgImg = if (Test-Path (Ruta 'skins\logo\logo.png')) { Cargar-Img 'skins\logo\logo.png' } else { $null }
    $script:lgImg2 = if (Test-Path (Ruta 'skins\logo\tung.png')) { Cargar-Img 'skins\logo\tung.png' } else { $null }
    $script:lgImg3 = if (Test-Path (Ruta 'skins\logo\randy.png')) { Cargar-Img 'skins\logo\randy.png' } else { $null }
    $script:iRecursos = @($script:lgImg, $script:lgImg2, $script:lgImg3)
    $script:iDespues = { Efecto-Entrada $null }
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAlias'
        # aparece poco a poco y se apaga al final
        $a = if ($p -lt 20) { $p / 20.0 } elseif ($p -gt 112) { [Math]::Max(0.0, (128 - $p) / 16.0) } else { 1.0 }
        $alto = if ($script:lgImg) { $H * 0.56 } else { 0 }
        if ($script:lgImg) {
            # el panda y, a su lado, su compañero; los dos de busto y apoyados a la misma altura
            $z = 1 + $p * 0.0008
            $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$a
            $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
            $dh = $alto * $z; $dw = $script:lgImg.Width * $dh / $script:lgImg.Height
            $suelo = $H * 0.66 - 8; $th2 = [Math]::Min($dh * $AltoTung, $suelo - 6); $dh = [Math]::Min($dh, $th2 / $AltoTung); $dw = $script:lgImg.Width * $dh / $script:lgImg.Height; $tw2 = if ($script:lgImg2) { $script:lgImg2.Width * $th2 / $script:lgImg2.Height } else { 0 }
            # a la izquierda Randy (solo la parte de arriba), con los ojos a la altura de los del panda
            $rh = $dh * 0.92; $rw = if ($script:lgImg3) { $script:lgImg3.Width * $rh / $script:lgImg3.Height } else { 0 }
            $total = $(if ($script:lgImg3) { $rw * 0.82 } else { 0 }) + $dw + $(if ($script:lgImg2) { $tw2 - $dw * 0.06 } else { 0 })
            # si no cabe (ventana estrecha), se encoge todo un poco
            $esc = [Math]::Min(1.0, ($W - 16) / [Math]::Max(1.0, $total))
            $dh *= $esc; $dw *= $esc; $th2 *= $esc; $tw2 *= $esc; $rh *= $esc; $rw *= $esc; $total *= $esc
            $x0 = $W / 2 - $total / 2
            $xp = $x0 + $(if ($script:lgImg3) { $rw * 0.82 } else { 0 })
            if ($script:lgImg3) { $g.DrawImage($script:lgImg3, (New-Object System.Drawing.Rectangle([int]$x0, [int]($suelo - $dh + $dh * 0.104), [int]$rw, [int]$rh)), 0, 0, $script:lgImg3.Width, $script:lgImg3.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia) }
            $g.DrawImage($script:lgImg, (New-Object System.Drawing.Rectangle([int]$xp, [int]($suelo - $dh), [int]$dw, [int]$dh)), 0, 0, $script:lgImg.Width, $script:lgImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
            if ($script:lgImg2) { $g.DrawImage($script:lgImg2, (New-Object System.Drawing.Rectangle([int]($xp + $dw * 0.94), [int]($suelo - $th2), [int]$tw2, [int]$th2)), 0, 0, $script:lgImg2.Width, $script:lgImg2.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia) }
            $ia.Dispose()
        }
        # nombre de la empresa con líneas a los lados
        $ty = if ($script:lgImg) { $H * 0.66 } else { $H * 0.38 }
        $f1 = FntP('Georgia', 22, [System.Drawing.FontStyle]::Bold)
        $tit = 'J O S E P A B L I N I    C O R P O R A T I O N'
        $tw = $g.MeasureString($tit, $f1).Width
        # en ventanas estrechas la letra se encoge para que quepa
        if ($tw -gt $W - 150) { $f1 = FntP('Georgia', (22 * ($W - 150) / $tw), [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($tit, $f1).Width }
        $blanco = New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $a)) 236 236 236))
        $g.DrawString($tit, $f1, $blanco, [float]($W / 2 - $tw / 2), [float]$ty)
        $ln = New-Object System.Drawing.Pen((ARGB ([int](150 * $a)) 200 200 200), 1)
        $g.DrawLine($ln, [float]($W / 2 - $tw / 2 - 70), [float]($ty + 17), [float]($W / 2 - $tw / 2 - 12), [float]($ty + 17))
        $g.DrawLine($ln, [float]($W / 2 + $tw / 2 + 12), [float]($ty + 17), [float]($W / 2 + $tw / 2 + 70), [float]($ty + 17)); $ln.Dispose()
        # lema: aparece un poco después
        if ($p -ge 30) {
            $b = [Math]::Min(1.0, ($p - 30) / 14.0) * $a
            $f2 = FntP('Georgia', 13, [System.Drawing.FontStyle]::Italic)
            $lema = 'Fear the Spaggety Code, Build the Larp'
            $lw = $g.MeasureString($lema, $f2).Width
            if ($lw -gt $W - 40) { $f2 = FntP('Georgia', (13 * ($W - 40) / $lw), [System.Drawing.FontStyle]::Italic); $lw = $g.MeasureString($lema, $f2).Width }
            $g.DrawString($lema, $f2, (New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $b)) 160 160 160))), [float]($W / 2 - $lw / 2), [float]($ty + 44))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { try { if ($script:aj.Sonido) { (New-Object System.Media.SoundPlayer((Ruta 'skins\logo\logo.wav'))).Play() } } catch {} } }
    Intro-Overlay 130 $pintar $alTick ''
}
function Intro-Overlay($total, $pintar, $alTick, $final) {
    $script:transicion = $true
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0)
    $ov.Size = $form.ClientSize
    $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $script:iPintar = $pintar; $script:iTick = $alTick
    $ov.Add_Paint({
        $_.Graphics.ScaleTransform($script:K, $script:K)
        & $script:iPintar $_.Graphics ([int]($this.Width / $script:K)) ([int]($this.Height / $script:K)) $script:iPaso
    })
    # botón SALTAR abajo a la derecha (en todas las intros)
    $sk = New-Object System.Windows.Forms.Button
    $sk.Text = 'SALTAR  ▶▶'; $sk.FlatStyle = 'Flat'; $sk.Font = Fnt('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $sk.ForeColor = [System.Drawing.Color]::White; $sk.BackColor = (C 18 18 22); $sk.Cursor = 'Hand'
    $sk.FlatAppearance.BorderColor = [System.Drawing.Color]::White; $sk.FlatAppearance.BorderSize = [Math]::Max(1, [int](1.5 * $script:K))
    $sk.FlatAppearance.MouseOverBackColor = (C 70 70 84); $sk.FlatAppearance.MouseDownBackColor = (C 120 120 140)
    $sk.Size = New-Object System.Drawing.Size([int](100 * $script:K), [int](28 * $script:K))
    $sk.Location = New-Object System.Drawing.Point(($ov.Width - $sk.Width - [int](12 * $script:K)), ($ov.Height - $sk.Height - [int](12 * $script:K)))
    $sk.Anchor = 'Bottom, Right'
    $sk.Add_Click({ Saltar-Intro })
    $ov.Controls.Add($sk)
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:iOv = $ov; $script:iPaso = 0; $script:iTotal = $total; $script:iFinal = $final
    $iTimer.Start()
}
# salta la intro que esté sonando: corta sus sonidos y va directo al final
function Saltar-Intro {
    if (-not $script:iOv) { return }
    $script:bSaltar = $true; $script:grSaltar = $true; $script:ppSaltar = $true
    if ($script:skin.Estilo -eq 'pop') { Tetra-Intro-Terminar }
    if ($script:skin.Estilo -eq 'clima') { $script:wiSaltar = $true; Wg-Intro-Terminar }
    if ($script:skin.Estilo -eq 'pintor') { $script:prSaltarI = $true }
    foreach ($r in @($script:reproductores)) { try { $r.Stop() } catch {} }
    $script:pzMusica = $null
    if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
}

# --- "GUILLOTINA IS COMING FOR YOU!": el callejón a toda velocidad con la radio WMEW 99.9, ella bajo la farola,
#     el cartel de papel y una mandíbula de dientes negros que se come la pantalla ---
# Va sincronizada con el audio de la radio (unos 17 s), no con los fotogramas. Un clic la salta.
# Momentos de la intro (en milisegundos desde que empieza el audio):
$GuiTiempos = @{ CambioFoto = 800; Jefa = 8000; Cae = 8350; Aterriza = 8600; Cartel = 12000; Mordisco = 14800; Fin = 16300 }
# dónde está la luz de la farola en intro_jefa.jpg (en proporción de la imagen) y el alto de Guillotina
$GuiFarola = @{ X = 0.764; Suelo = 0.577; Alto = 0.407 }
# dibuja una imagen llenando la pantalla, con zoom alrededor del punto (fx, fy) de la imagen; devuelve dónde quedó
function Dibujar-Cubriendo($g, $img, $W, $H, $z, $fx, $fy) {
    $s0 = [Math]::Max($W / $img.Width, $H / $img.Height); $s = $s0 * $z
    $px = ($W - $img.Width * $s0) / 2 + $fx * $img.Width * $s0; $py = ($H - $img.Height * $s0) / 2 + $fy * $img.Height * $s0
    $x = $px - $fx * $img.Width * $s; $y = $py - $fy * $img.Height * $s
    $g.DrawImage($img, [float]$x, [float]$y, [float]($img.Width * $s), [float]($img.Height * $s))
    return @{ S = $s; X = $x; Y = $y }
}
# la mandíbula: dientes negros que bajan desde arriba y suben desde abajo (c = 0 abierta, 1 cerrada)
function Dibujar-Mandibula($g, $W, $H, $c) {
    $n = 9; $tw = $W / $n; $th = 46; $neg = [System.Drawing.Brushes]::Black
    $modo = $g.SmoothingMode; $g.SmoothingMode = 'None'   # sin suavizado: así no quedan rayas entre los dientes
    $yb = -$th + $c * ($H / 2 - $th / 2 + $th)          # borde de abajo de la mandíbula de arriba
    $yt = $H + $th - $c * ($H / 2 - $th / 2 + $th)      # borde de arriba de la mandíbula de abajo
    $g.FillRectangle($neg, 0, 0, [float]$W, [float][Math]::Max(0, $yb))
    $g.FillRectangle($neg, 0, [float]$yt, [float]$W, [float][Math]::Max(0, $H - $yt))
    for ($i = -1; $i -le $n; $i++) {
        $x = $i * $tw
        $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, [float]$yb)), (New-Object System.Drawing.PointF([float]($x + $tw), [float]$yb)), (New-Object System.Drawing.PointF([float]($x + $tw / 2), [float]($yb + $th)))))
        $x2 = $x + $tw / 2
        $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x2, [float]$yt)), (New-Object System.Drawing.PointF([float]($x2 + $tw), [float]$yt)), (New-Object System.Drawing.PointF([float]($x2 + $tw / 2), [float]($yt - $th)))))
    }
    if ($c -ge 0.999) { $g.FillRectangle($neg, 0, 0, [float]$W, [float]$H) }
    $g.SmoothingMode = $modo
}
# cuánto está cerrada la mandíbula: muerde, se abre un poco y vuelve a morder
function Cierre-Mandibula($t) {
    if ($t -lt 0) { return 0.0 }
    if ($t -lt 220) { $q = $t / 220.0; return $q * $q }
    if ($t -lt 380) { return 1.0 - 0.45 * (($t - 220) / 160.0) }
    if ($t -lt 560) { return 0.55 + 0.45 * (($t - 380) / 180.0) }
    return 1.0
}
function Transicion-Boss($final) {
    $k = $script:skin
    $script:bFotos = @($k.IntroFotos | ForEach-Object { Cargar-Img $_ } | Where-Object { $_ })
    $script:bJefa = Cargar-Img $k.IntroJefa; $script:bGui = Cargar-Img $k.IntroGuillotina
    $script:bCartel = Cargar-Img $k.IntroCartel; $script:bMarco = Cargar-Img $k.IntroMarco
    $script:iRecursos = @($script:bFotos) + @($script:bJefa, $script:bGui, $script:bCartel, $script:bMarco)
    $script:bT0 = 0; $script:bHechos = @{}; $script:bAudio = $null; $script:bSaltar = $false
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $T = $GuiTiempos
        $ms = if ($script:bT0 -gt 0) { [Environment]::TickCount - $script:bT0 } else { 0 }
        $g.Clear([System.Drawing.Color]::Black)
        # temblor: al cambiar de foto, al aterrizar ella y al caer el cartel
        $sx = 0; $sy = 0
        $temblor = ($ms -lt $T.Jefa -and ($ms % $T.CambioFoto) -lt 120) -or ($ms -ge $T.Aterriza -and $ms -lt $T.Aterriza + 450) -or ($ms -ge $T.Cartel -and $ms -lt $T.Cartel + 350)
        if ($temblor) { $sx = $Rnd.Next(-7, 8); $sy = $Rnd.Next(-5, 6) }
        $st = $g.Save(); $g.TranslateTransform([float]$sx, [float]$sy)
        if ($ms -lt $T.Jefa) {
            # 1) las fotos del callejón pasan rápido, cada una con un poco de zoom
            if ($script:bFotos.Count -gt 0) {
                $i = [int][Math]::Floor($ms / $T.CambioFoto) % $script:bFotos.Count; $q = ($ms % $T.CambioFoto) / $T.CambioFoto
                [void](Dibujar-Cubriendo $g $script:bFotos[$i] $W $H (1.03 + 0.07 * $q) 0.5 0.5)
            }
            if (($ms % $T.CambioFoto) -lt 70) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 255, 255, 255))), -10, -10, ($W + 20), ($H + 20)) }
        } elseif ($script:bJefa) {
            # 2) el callejón de la jefa, acercándose poco a poco a la farola; ella cae bajo la luz
            $z = 1.02 + [Math]::Min(1.0, ($ms - $T.Jefa) / 7000.0) * 0.14
            $m = Dibujar-Cubriendo $g $script:bJefa $W $H $z $GuiFarola.X 0.5
            if ($script:bGui -and $ms -ge $T.Cae) {
                $gh = $GuiFarola.Alto * $script:bJefa.Height * $m.S; $gw = $script:bGui.Width * $gh / $script:bGui.Height
                $cx = $m.X + $GuiFarola.X * $script:bJefa.Width * $m.S; $suelo = $m.Y + $GuiFarola.Suelo * $script:bJefa.Height * $m.S
                $tc = [Math]::Min(1.0, ($ms - $T.Cae) / [double]($T.Aterriza - $T.Cae)); $caida = (1 - $tc * $tc) * ($suelo + 20)   # ojo: $T son los tiempos (PowerShell no distingue mayúsculas)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](110 * $tc), 0, 0, 0))), [float]($cx - $gw * 0.45), [float]($suelo - 9), [float]($gw * 0.9), 16)
                $g.DrawImage($script:bGui, [float]($cx - $gw / 2), [float]($suelo - $gh - $caida), [float]$gw, [float]$gh)
                # polvo al aterrizar
                if ($ms -ge $T.Aterriza -and $ms -lt $T.Aterriza + 600) {
                    $q = ($ms - $T.Aterriza) / 600.0
                    foreach ($dx in @(-1, 1)) { for ($j = 0; $j -lt 3; $j++) { $r = 10 + $q * 22 + $j * 5; $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](120 * (1 - $q)), 200, 200, 200))), [float]($cx + $dx * ($gw * 0.42 + $q * 40 + $j * 14) - $r / 2), [float]($suelo - $r * 0.8), [float]$r, [float]($r * 0.7)) } }
                }
            }
        }
        # el marco de cables, postes y basura por delante de todo
        if ($script:bMarco) { [void](Dibujar-Cubriendo $g $script:bMarco $W $H 1.0 0.5 0.5) }
        $g.Restore($st)
        # 3) el cartel de papel cae de golpe
        if ($script:bCartel -and $ms -ge $T.Cartel) {
            $q = ($ms - $T.Cartel) / 160.0; $esc = 1.0 + 0.9 * [Math]::Max(0.0, 1 - $q)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]([Math]::Min(1.0, $q) * 120), 0, 0, 0))), 0, 0, $W, $H)
            $ch = $H * 0.74; $cw = $script:bCartel.Width * $ch / $script:bCartel.Height
            $st = $g.Save(); $g.TranslateTransform([float]($W / 2 + $sx), [float]($H / 2 + $sy)); $g.RotateTransform(-2); $g.ScaleTransform([float]$esc, [float]$esc)
            $g.DrawImage($script:bCartel, [float](-$cw / 2), [float](-$ch / 2), [float]$cw, [float]$ch)
            $g.Restore($st)
        }
        # 4) la mandíbula se come la pantalla
        if ($ms -ge $T.Mordisco) { Dibujar-Mandibula $g $W $H (Cierre-Mandibula ($ms - $T.Mordisco)) }
    }
    $alTick = {
        param($ov, $p)
        $T = $GuiTiempos
        if ($p -eq 1) {
            $script:bT0 = [Environment]::TickCount
            # la radio; se guarda el reproductor para poder pararla si se salta la intro
            if ($script:aj.Sonido) { $n = $script:reproductores.Count; Sonido 'radio'; if ($script:reproductores.Count -gt $n -or $script:reproductores.Count -ge 12) { $script:bAudio = $script:reproductores[$script:reproductores.Count - 1] } }
        }
        $ms = [Environment]::TickCount - $script:bT0
        foreach ($ev in @(@($T.Aterriza, 'golpe'), @($T.Cartel, 'intro'), @(($T.Mordisco + 220), 'mordisco'), @(($T.Mordisco + 560), 'mordisco2'))) {
            if ($ms -ge $ev[0] -and -not $script:bHechos.ContainsKey($ev[1])) { $script:bHechos[$ev[1]] = $true; Sonido ($ev[1] -replace '2$', '') }
        }
        if ($script:bSaltar -or $ms -ge $T.Fin) {
            if ($script:bSaltar -and $script:bAudio) { try { $script:bAudio.Stop() } catch {} }
            if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    # un clic salta la intro
    $script:iOv.Add_MouseDown({ $script:bSaltar = $true })
    $script:iOv.Cursor = 'Hand'
}

# --- inicio de jornada en L Corp ---
# --- intro de Velvet: pantalla de carga de Gunsaw con su ficha de especie, una telaraña que cubre la pantalla y ella bajando por su hilo ---
# La música es la suya (Night of the Creeps): empieza con la intro y sigue sonando después.
$VvIntro = @{ Ficha = 1500; Red = 4900; Baja = 6200; Nombre = 7300; Fin = 9800 }
function Transicion-Velvet($final) {
    $k = $script:skin
    $script:viCarga = Cargar-Img $k.Carga; $script:viVel = Cargar-Img 'skins\velvet\velvet.png'
    $script:iRecursos = @($script:viCarga, $script:viVel)
    $script:viT0 = 0; $script:viHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
        $VT = $VvIntro; $k = $script:skin
        $ms = if ($script:viT0 -gt 0) { [Environment]::TickCount - $script:viT0 } else { 0 }
        $g.Clear((C 12 5 10))
        $blanco = New-Object System.Drawing.SolidBrush((C 222 218 226))
        if ($ms -lt $VT.Red) {
            # 1) la pantalla de carga de Gunsaw: su ilustración en blanco y el título; 2) su ficha de especie
            $lin = New-Object System.Drawing.Pen((ARGB 18 255 255 255), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($lin, 0, $y, $W, $y) }; $lin.Dispose()
            if ($script:viCarga) {
                $ch = $H * 0.9; $cw = $script:viCarga.Width * $ch / $script:viCarga.Height
                $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float][Math]::Min(1.0, $ms / 700.0)
                $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                $g.DrawImage($script:viCarga, (New-Object System.Drawing.Rectangle([int]($W - $cw - 30), [int](($H - $ch) / 2), [int]$cw, [int]$ch)), 0, 0, $script:viCarga.Width, $script:viCarga.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia); $ia.Dispose()
            }
            $n = [Math]::Min(6, [Math]::Max(0, [int](($ms - 150) / 80)))
            Texto-Color $g ('GUNSAW'.Substring(0, $n)) 'Consolas' 30 26 14 (C 230 30 50) (C 20 4 8) 4
            if ($ms -lt $VT.Ficha) {
                $g.DrawString(('cargando' + ('.' * ([int]($ms / 300) % 4))), (FntP('Consolas', 10)), (New-Object System.Drawing.SolidBrush((C 150 140 156))), 30, 64)
            } else {
                $g.DrawString('VELVET', (FntP('Consolas', 20, [System.Drawing.FontStyle]::Bold)), $blanco, 28, 56)
                $f9 = FntP('Consolas', 9)
                $lineas = @($k.IntroLineas)
                for ($i = 0; $i -lt $lineas.Count; $i++) {
                    $t0 = $VT.Ficha + 300 + $i * 380; if ($ms -lt $t0) { break }
                    $nn = [Math]::Min($lineas[$i].Length, [int](($ms - $t0) / 12))
                    $g.DrawString($lineas[$i].Substring(0, $nn), $f9, $blanco, 30, [float](96 + $i * 16))
                }
                $tStats = $VT.Ficha + 300 + $lineas.Count * 380
                if ($ms -ge $tStats) {
                    $j = 0; foreach ($s in @($k.IntroStats) + @($k.IntroPie)) { Texto-Marcado $g $s $f9 30 (200 + $j * 16); $j++ }
                }
            }
        } else {
            # 3) una telaraña crece desde arriba y cubre la pantalla
            $q = [Math]::Min(1.0, ($ms - $VT.Red) / 1200.0)
            Vv-Red $g ($W * 0.6) 0 ($H * 1.5 * $q) (ARGB 190 230 225 235) 13 8 172 ([Math]::Max(1, [int](8 * $q)))
            Vv-Red $g 0 0 ($H * 0.8 * $q) (ARGB 120 230 225 235) 6 0 90 ([Math]::Max(1, [int](5 * $q)))
            # 4) Velvet baja por su hilo, se para y le brillan los ojos
            if ($ms -ge $VT.Baja -and $script:viVel) {
                $q2 = [Math]::Min(1.0, ($ms - $VT.Baja) / 900.0); $ee = 1 - [Math]::Pow(1 - $q2, 3)
                $vh = $H * 0.92; $vw = $script:viVel.Width * $vh / $script:viVel.Height
                $vx = $W * 0.74 - $vw / 2 + [Math]::Sin($ms / 700.0) * 3; $vy = (1 - $ee) * (- $vh) + $ee * ($H - $vh)
                $g.DrawLine((New-Object System.Drawing.Pen((ARGB 200 230 225 235), 1.5)), [float]($vx + $vw * 0.47), 0, [float]($vx + $vw * 0.47), [float]($vy + $vh * 0.06))
                $g.DrawImage($script:viVel, [float]$vx, [float]$vy, [float]$vw, [float]$vh)
                $al = [Math]::Max(0.0, [Math]::Min(1.0, ($ms - $VT.Baja - 900) / 400.0))
                if ($al -gt 0) {
                    foreach ($o in $k.Ojos) {
                        $ox = $vx + $o[0] * $vw; $oy = $vy + $o[1] * $vh; $rad = 12 * $o[2]
                        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($ox - $rad), [float]($oy - $rad), [float](2 * $rad), [float](2 * $rad))
                        $brillo = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $brillo.CenterColor = (ARGB ([int](230 * $al)) 255 40 60); $brillo.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 255 0 30))
                        $g.FillPath($brillo, $gp); $brillo.Dispose(); $gp.Dispose()
                    }
                }
            }
            if ($ms -ge $VT.Nombre) {
                $q = [Math]::Min(1.0, ($ms - $VT.Nombre) / 400.0); $ee = 1 - [Math]::Pow(1 - $q, 3)
                Texto-Color $g 'VELVET' 'Consolas' 54 (36 - (1 - $ee) * 320) 60 (C 236 228 232) (C 140 10 30) 8
                if ($ms -ge $VT.Nombre + 450) { Texto-Color $g 'Arachnid  ·  14/14 species  ·  Gunsaw' 'Consolas' 13 42 132 (C 230 60 80) (C 20 4 8) 4 }
                if ($ms -ge $VT.Nombre + 1000) {
                    $txt = 'Hola, cielo... ¿te has perdido?'; $n = [Math]::Min($txt.Length, [int](($ms - $VT.Nombre - 1000) / 60))
                    Texto-Color $g $txt.Substring(0, $n) 'Segoe UI' 19 44 170 (C 255 255 255) (C 90 10 30) 5
                }
            }
        }
        $blanco.Dispose()
        # sale del negro al principio
        if ($ms -lt 400) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * (1 - $ms / 400.0)), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $VT = $VvIntro
        if ($p -eq 1) { $script:viT0 = [Environment]::TickCount; Vv-Reset; Vv-Musica-On }
        $ms = [Environment]::TickCount - $script:viT0
        foreach ($ev in @(@($VT.Red, 'escupe'), @($VT.Baja, 'siseo'), @(($VT.Baja + 900), 'latido'))) {
            if ($ms -ge $ev[0] -and -not $script:viHechos.ContainsKey($ev[1])) { $script:viHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $VT.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- intro de Angela: el logo de Lobotomy Corporation, el cartel del día con Angela en su silla y ella en la sala de monitores ---
# La música es la suya (Neutral01): empieza con la intro y sigue sonando después. Al final se abre como dos puertas.
$AgIntro = @{ Dia = 2600; Angela = 5400; Nombre = 6000; Fin = 8800 }
function Transicion-Lobo($final) {
    $k = $script:skin
    if (-not $script:bmpHexIntro) { $script:bmpHexIntro = Fondo-Hexagonos 616 344 ([System.Drawing.Color]::FromArgb(60, 255, 170, 40)) }
    $script:aiDia = Cargar-Img $k.IntroDia; $script:aiFondo = Cargar-Img $k.FondoImg; $script:aiAng = Cargar-Img 'skins\angela\a_angela.png'
    $script:iRecursos = @($script:aiDia, $script:aiFondo, $script:aiAng)
    $script:aiT0 = 0; $script:aiHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
        $AT = $AgIntro
        $ms = if ($script:aiT0 -gt 0) { [Environment]::TickCount - $script:aiT0 } else { 0 }
        $g.Clear((C 6 8 11))
        $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
        if ($ms -lt $AT.Dia) {
            # 1) el logo: hexágonos, LOBOTOMY CORPORATION escribiéndose y el lema
            $g.DrawImage($script:bmpHexIntro, 0, 0, $W, $H)
            $t1 = 'LOBOTOMY CORPORATION'; $n = [Math]::Min($t1.Length, [Math]::Max(0, [int](($ms - 200) / 55)))
            $g.DrawString($t1.Substring(0, $n), (FntP('Bahnschrift', 26, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 176 50))), (New-Object System.Drawing.RectangleF(0, ($H / 2 - 64), $W, 46)), $fmt)
            if ($ms -ge 1500) { $g.DrawString('Face the Fear, Build the Future', (FntP('Bahnschrift', 12)), (New-Object System.Drawing.SolidBrush((C 80 210 200))), (New-Object System.Drawing.RectangleF(0, ($H / 2 - 14), $W, 24)), $fmt) }
            if ($ms -ge 1900) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 176 50))), [float]($W / 2 - 170), [float]($H / 2 + 18), 340, 2) }
        } elseif ($ms -lt $AT.Angela -and $script:aiDia) {
            # 2) Angela en su silla de la sala de control y el cartel rojo del día, como en el juego
            [void](Dibujar-Cubriendo $g $script:aiDia $W $H (1.0 + ($ms - $AT.Dia) / 12000.0) 0.55 0.5)
            $q = [Math]::Min(1.0, ($ms - $AT.Dia) / 350.0)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 36 36))), [float](24 - (1 - $q) * 200), 22, 168, 48)
            $g.DrawString("DÍA $($script:aj.AngelaDia)", (FntP('Bahnschrift', 24, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, [float](34 - (1 - $q) * 200), 24)
            if ($ms -ge $AT.Dia + 900) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 6 8 11))), 0, ($H - 40), $W, 40)
                $g.DrawString('Manager conectado.  Angela: en línea.', (FntP('Bahnschrift', 11)), (New-Object System.Drawing.SolidBrush((C 220 232 240))), 24, [float]($H - 32))
            }
        } elseif ($script:aiFondo) {
            # 3) la sala de monitores: Angela entra desde la derecha y sale su nombre
            [void](Dibujar-Cubriendo $g $script:aiFondo $W $H (1.0 + ($ms - $AT.Angela) / 9000.0) 0.6 0.5)
            Degradado $g 0 0 ($W * 0.62) $H (ARGB 220 8 10 14) (ARGB 0 8 10 14) 0
            if ($script:aiAng) {
                $q = [Math]::Min(1.0, ($ms - $AT.Angela) / 600.0); $ee = 1 - [Math]::Pow(1 - $q, 3)
                $nh = $H * 0.98; $nw = $script:aiAng.Width * $nh / $script:aiAng.Height
                $g.DrawImage($script:aiAng, [float]($W * 0.78 - $nw / 2 + (1 - $ee) * $W * 0.4), [float]($H - $nh + [Math]::Sin($ms / 600.0) * 2), [float]$nw, [float]$nh)
            }
            if ($ms -ge $AT.Nombre) {
                $q = [Math]::Min(1.0, ($ms - $AT.Nombre) / 400.0); $ee = 1 - [Math]::Pow(1 - $q, 3)
                Texto-Color $g 'ANGELA' 'Bahnschrift' 56 (40 - (1 - $ee) * 320) 58 (C 236 240 244) (C 40 30 10) 8
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 176 50))), [float](44 - (1 - $ee) * 320), 128, 230, 3)
                if ($ms -ge $AT.Nombre + 450) { Texto-Color $g 'Asistente IA  ·  Lobotomy Corporation' 'Bahnschrift' 14 46 138 (C 255 176 50) (C 20 14 4) 4 }
                if ($ms -ge $AT.Nombre + 1000) {
                    $txt = 'Buenos días, Manager.'; $n = [Math]::Min($txt.Length, [int](($ms - $AT.Nombre - 1000) / 60))
                    Texto-Color $g $txt.Substring(0, $n) 'Bahnschrift' 20 48 176 (C 255 255 255) (C 30 40 50) 5
                }
            }
        }
        # sale del negro al principio
        if ($ms -lt 500) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * (1 - $ms / 500.0)), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $AT = $AgIntro
        if ($p -eq 1) { $script:aiT0 = [Environment]::TickCount; Ag-Reset; Ag-Musica-On }
        $ms = [Environment]::TickCount - $script:aiT0
        foreach ($ev in @(@(300, 'trabajo'), @($AT.Dia, 'pebox'), @($AT.Angela, 'fin'))) {
            if ($ms -ge $ev[0] -and -not $script:aiHechos.ContainsKey($ev[1])) { $script:aiHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $AT.Fin -and $script:iPaso -lt $script:iTotal - 10) { $script:iPaso = $script:iTotal - 10 }
        # al final se abre como dos puertas desde el centro
        if ($p -gt $script:iTotal - 10) {
            $W = $ov.Width; $H = $ov.Height; $banda = [int]($W * ($p - ($script:iTotal - 10)) / 10)
            $reg = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
            $reg.Exclude((New-Object System.Drawing.Rectangle([int](($W - $banda) / 2), 0, $banda, $H)))
            $viejo = $ov.Region; $ov.Region = $reg; if ($viejo) { $viejo.Dispose() }
        }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- la mira del francotirador de Mikaela ---
function Transicion-Scope($final) {
    $script:scRet = Cargar-Img $script:skin.Gif; $script:scPlaca = Cargar-Img $script:skin.TituloImg
    $script:iRecursos = @($script:scRet, $script:scPlaca)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear([System.Drawing.Color]::Black)
        $amp = [Math]::Max(0.0, 1 - $p / 24.0)
        $cx = $W / 2 + [Math]::Sin($p / 2.5) * 80 * $amp; $cy = $H / 2 + [Math]::Cos($p / 3.3) * 38 * $amp; $r = 118
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse([float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
        $g.SetClip($path)
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (C 57 72 191), (C 229 45 45), 35)
        $g.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
        $s = [int](250 * (1.0 + [Math]::Min($p, 30) * 0.012))
        if ($script:scRet) { $g.DrawImage($script:scRet, [int]($W / 2 - $s / 2), [int]($H / 2 - $s / 2), $s, $s) }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
        $g.DrawLine($pen, [float]($cx - $r), [float]$cy, [float]($cx + $r), [float]$cy); $g.DrawLine($pen, [float]$cx, [float]($cy - $r), [float]$cx, [float]($cy + $r))
        for ($q = -3; $q -le 3; $q++) { if ($q) { $g.DrawLine($pen, [float]($cx + $q * 25), [float]($cy - 5), [float]($cx + $q * 25), [float]($cy + 5)) } }
        $pen.Dispose()
        $g.FillEllipse([System.Drawing.Brushes]::Red, [float]($cx - 4), [float]($cy - 4), 8, 8)
        $g.ResetClip()
        $g.DrawEllipse((New-Object System.Drawing.Pen((C 30 30 30), 10)), [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
        $path.Dispose()
        $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
        if ($p -lt 30) {
            if ($p -lt 12) { $txt = 'APUNTANDO...'; $col = [System.Drawing.Brushes]::White } elseif ($p -lt 22) { $txt = 'CHARGED'; $col = [System.Drawing.Brushes]::Yellow } else { $txt = 'OVERCHARGED'; $col = [System.Drawing.Brushes]::Red }
            $g.DrawString($txt, (FntP('Arial Black', 12)), $col, (New-Object System.Drawing.RectangleF(0, ($H - 34), $W, 30)), $fmt)
        }
        if ($p -ge 31) {
            Dibujar-Hit $g ($W / 2) ($H / 2) 30
            if ($script:scPlaca) { $g.DrawImage($script:scPlaca, [int]($W / 2 - 150), 8, 300, 94) }
            Texto-Borde $g 'THE MVP' 'Arial Black' 30 ($W / 2 - 92) ($H - 66) (C 0 255 0)
        }
        if ($p -ge 30 -and $p -le 33) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb((34 - $p) * 60, 255, 255, 255))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        switch ($p) { 1 { Sonido 'apuntar' } 12 { Sonido 'carga' } 22 { Sonido 'sobrecarga' } 30 { Sonido 'disparoMax' } }
        if ($p -gt 44) { $ov.Left -= [int]($ov.Width / 6) }
    }
    Intro-Overlay 51 $pintar $alTick $final
}

# --- pantalla de selección de personaje de Gunsaw (Velvet y Dune) ---
function Transicion-Gunsaw($final) {
    $script:gaArte = Cargar-Img $script:skin.Arte
    $script:iRecursos = @($script:gaArte)
    $pintar = {
        param($g, $W, $H, $p)
        $k = $script:skin
        $g.Clear((C 24 13 28)); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
        $lin = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(18, 255, 255, 255), 1)
        for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($lin, 0, $y, $W, $y) }
        $lin.Dispose()
        $blanco = New-Object System.Drawing.SolidBrush((C 222 218 226)); $gris = New-Object System.Drawing.Pen((C 125 112 130), 1)
        if ($p -ge 2) { $g.DrawString('A-D to switch characters', (FntP('Consolas', 9, [System.Drawing.FontStyle]::Bold)), $blanco, 214, 6) }
        $n = [Math]::Min($k.Titulo.Length, [Math]::Max(0, $p - 3))
        $g.DrawString($k.Titulo.Substring(0, $n), (FntP('Consolas', 28, [System.Drawing.FontStyle]::Bold)), $blanco, 14, 10)
        if ($p -ge 8) { $g.DrawString('14/14 species unlocked', (FntP('Consolas', 9)), (New-Object System.Drawing.SolidBrush((C 190 184 196))), 18, 58) }
        if ($p -ge 4 -and $script:gaArte -and -not ($p -lt 16 -and $Rnd.Next(4) -eq 0)) {
            $x = 380 + [Math]::Max(0, 12 - $p) * 18
            $g.DrawImage($script:gaArte, [int]$x, 8, 226, 270)
        }
        if ($p -ge 10) {
            $g.DrawString('Character', (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), $blanco, 16, 84)
            $g.DrawRectangle($gris, 16, 104, 354, 118)
            $quedan = ($p - 10) * 7; $y = 110
            foreach ($l in $k.IntroLineas) {
                if ($quedan -le 0) { break }
                $t = $l.Substring(0, [Math]::Min($l.Length, $quedan)); $quedan -= $l.Length
                $g.DrawString($t, (FntP('Consolas', 7.5)), $blanco, 22, $y); $y += 18
            }
        }
        if ($p -ge 30) {
            $g.DrawString('Gameplay', (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), $blanco, 16, 226)
            $g.DrawRectangle($gris, 16, 246, 262, 52)
            $y = 250; foreach ($l in $k.IntroStats) { Texto-Marcado $g $l (FntP('Consolas', 7.5, [System.Drawing.FontStyle]::Bold)) 22 $y; $y += 12 }
            foreach ($l in $k.IntroPie) { Texto-Marcado $g $l (FntP('Consolas', 7.5, [System.Drawing.FontStyle]::Bold)) 22 $y; $y += 12 }
            $g.DrawRectangle($gris, 284, 246, 86, 52)
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString("Starting weapon:`n$($k.Arma)", (FntP('Consolas', 7, [System.Drawing.FontStyle]::Bold)), $blanco, (New-Object System.Drawing.RectangleF(284, 252, 86, 44)), $fmt)
        }
        if ($p -ge 40 -and ($p % 6) -lt 4) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 28 44))), ($W - 150), ($H - 36), 136, 24)
            $g.DrawRectangle($gris, ($W - 150), ($H - 36), 136, 24)
            $g.DrawString('BACK TO LEVEL', (FntP('Consolas', 10, [System.Drawing.FontStyle]::Bold)), $blanco, ($W - 142), ($H - 33))
        }
        $marco = Ruta-Redonda 2 2 ($W - 4) ($H - 4) 26
        $g.DrawPath((New-Object System.Drawing.Pen((C 10 4 12), 6)), $marco); $marco.Dispose()
        $gris.Dispose(); $blanco.Dispose()
    }
    # al final el monitor "se apaga" hasta quedar en una línea y un punto
    $alTick = {
        param($ov, $p)
        if ($p -gt 50) {
            $W = $ov.Width; $H = $ov.Height
            if ($p -ge 57) { $rc = New-Object System.Drawing.Rectangle([int]($W / 2 - 8), [int]($H / 2 - 3), 16, 6) }
            else { $alto = [Math]::Max(4, [int]($H * (1 - ($p - 50) / 7.0))); $rc = New-Object System.Drawing.Rectangle(0, [int](($H - $alto) / 2), $W, $alto) }
            $viejo = $ov.Region; $ov.Region = New-Object System.Drawing.Region($rc); if ($viejo) { $viejo.Dispose() }
        }
    }
    Intro-Overlay 60 $pintar $alTick $final
}

# --- duelo al atardecer: plano general, primer plano de los ojos, "DON'T MOVE!", tres balazos y su cartel ---
function Transicion-Wanted($final) {
    $script:wpImg = Cargar-Img $script:skin.Cartel
    $script:wpCielo = $null; $script:wpSil = $null
    # silueta negra de Zodiac (el mismo dibujo, pintado de negro) para el contraluz
    if ($script:wpImg) {
        $sh = 300; $sw = [int]($script:wpImg.Width * $sh / $script:wpImg.Height)
        $script:wpSil = New-Object System.Drawing.Bitmap($sw, $sh)
        $gs = [System.Drawing.Graphics]::FromImage($script:wpSil); $gs.InterpolationMode = 'HighQualityBicubic'
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        $cm.Matrix00 = 0; $cm.Matrix11 = 0; $cm.Matrix22 = 0; $cm.Matrix40 = 0.13; $cm.Matrix41 = 0.04; $cm.Matrix42 = 0.08
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $gs.DrawImage($script:wpImg, (New-Object System.Drawing.Rectangle(0, 0, $sw, $sh)), 0, 0, $script:wpImg.Width, $script:wpImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $gs.Dispose(); $ia.Dispose()
    }
    $script:iRecursos = @($script:wpImg, $script:wpSil)
    $script:agujeros = New-Object System.Collections.ArrayList
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        # el atardecer se pinta una vez y se reutiliza
        if (-not $script:wpCielo) {
            $Z = $script:K
            $script:wpCielo = New-Object System.Drawing.Bitmap([int]($W * $Z), [int]($H * $Z))
            $gc = [System.Drawing.Graphics]::FromImage($script:wpCielo); $gc.SmoothingMode = 'AntiAlias'; $gc.ScaleTransform($Z, $Z)
            Pintar-Atardecer $gc 0 0 $W $H ($H * 0.66) ($W * 0.5) 78
            Cactus-Silueta $gc 70 ($H - 20) 200 (C 34 12 24)
            Cactus-Silueta $gc ($W - 90) ($H * 0.66 + 6) 60 (C 92 30 52)
            $gc.Dispose(); $script:iRecursos += $script:wpCielo
        }
        $sx = 0; $sy = 0
        if (($p -ge 32 -and $p -le 35) -or $p -in @(40, 41, 43, 44, 46, 47)) { $sx = $Rnd.Next(-9, 10); $sy = $Rnd.Next(-6, 7) }
        $barra = 0
        if ($p -lt 16) {
            # 1) plano general: el desierto al atardecer y una planta rodadora
            $g.DrawImage($script:wpCielo, 0, 0, $W, $H)
            Dibujar-Rodadora $g (-40 + $p * 34) ($H * 0.82 - [Math]::Abs([Math]::Sin($p * 0.6)) * 22) 22 ($p * 26)
            $barra = [Math]::Min(46, $p * 8)
        } elseif ($p -lt 30) {
            # 2) primer plano de los ojos (como en las pelis del oeste)
            $g.Clear((C 20 8 10))
            if ($script:wpImg) {
                $z = 1 + ($p - 16) * 0.012
                $sw = 400 / $z; $sh = 112 / $z
                $src = New-Object System.Drawing.RectangleF([float](405 - $sw / 2), [float](346 - $sh / 2), [float]$sw, [float]$sh)
                $g.DrawImage($script:wpImg, (New-Object System.Drawing.RectangleF(0, [float]($H * 0.5 - 100), [float]$W, 200)), $src, [System.Drawing.GraphicsUnit]::Pixel)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 255 90 30))), 0, 0, $W, $H)
            }
            $barra = $H * 0.5 - 100
        } else {
            # 3) contraluz delante del sol, "DON'T MOVE!", balazos y cartel
            $g.DrawImage($script:wpCielo, [float](-14 + $sx), [float](-10 + $sy), [float]($W + 28), [float]($H + 20))
            if ($script:wpSil) {
                $ch = $H * 0.86; $cw = $script:wpSil.Width * $ch / $script:wpSil.Height
                $cx = $W * 0.5 - $cw / 2 + $sx; $cy = $H - $ch - 4 + $sy
                if ($p -ge 50) { $cx = $cx + [Math]::Min(1.0, ($p - 50) / 6.0) * ($W * 0.2) }
                $g.DrawImage($script:wpSil, [float]$cx, [float]$cy, [float]$cw, [float]$ch)
                # al final se le ve en color
                if ($p -ge 50 -and $script:wpImg) {
                    $al = [float][Math]::Min(1.0, ($p - 50) / 6.0)
                    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = $al
                    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                    $g.DrawImage($script:wpImg, (New-Object System.Drawing.Rectangle([int]$cx, [int]$cy, [int]$cw, [int]$ch)), 0, 0, $script:wpImg.Width, $script:wpImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                    $ia.Dispose()
                }
            }
            if ($p -ge 32 -and $p -lt 50) {
                $e = [Math]::Max(1.0, 2.2 - ($p - 32) * 0.4)
                $st = $g.Save(); $g.TranslateTransform([float]($W / 2 + $sx), [float]($H * 0.42 + $sy)); $g.RotateTransform(-10); $g.ScaleTransform([float]$e, [float]$e)
                Texto-Color $g "DON'T MOVE!" 'EdmundMcMillen_INTLv4' 62 (-185) (-42) (C 235 46 34) (C 255 226 120) 12
                $g.Restore($st)
            }
            # agujeros de bala con el cristal roto
            foreach ($a in $script:agujeros) {
                $gr = New-Object System.Drawing.Pen((ARGB 200 255 255 255), 1.4)
                foreach ($k in 0..7) { $an = ($k * 45 + $a.R) * [Math]::PI / 180; $l = 18 + (($k * 7 + $a.R) % 22); $g.DrawLine($gr, [float]$a.X, [float]$a.Y, [float]($a.X + [Math]::Cos($an) * $l), [float]($a.Y + [Math]::Sin($an) * $l)) }
                $g.DrawEllipse($gr, [float]($a.X - 11), [float]($a.Y - 11), 22, 22); $gr.Dispose()
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 10 6 6))), [float]($a.X - 5), [float]($a.Y - 5), 10, 10)
                # humito
                if ($p -ge $a.P) { $hy = ($p - $a.P) * 2.5; $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int][Math]::Max(0, 120 - ($p - $a.P) * 5)) 230 220 210))), [float]($a.X - 6 + [Math]::Sin($p * 0.5) * 3), [float]($a.Y - 14 - $hy), 12, 12) }
            }
            if ($p -in @(40, 43, 46)) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 255 244 200))), 0, 0, $W, $H) }
            # título del cartel
            if ($p -ge 52) {
                $t = [Math]::Min(1.0, ($p - 52) / 5.0); $e = 1 - [Math]::Pow(1 - $t, 3)
                $tx = -360 + $e * 384
                Texto-Color $g 'ZODIAC' 'EdmundMcMillen_INTLv4' 76 ($tx + 5) 44 (ARGB 120 40 10 20) (ARGB 120 40 10 20) 14
                Texto-Color $g 'ZODIAC' 'EdmundMcMillen_INTLv4' 76 $tx 38 (C 255 214 90) (C 60 20 12) 14
            }
            if ($p -ge 58) {
                $t = [Math]::Min(1.0, ($p - 58) / 4.0); $wcin = 330 * $t
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 176 36 34))), 22, 138, [float]$wcin, 34)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 20 22))), 22, 168, [float]$wcin, 4)
                if ($t -ge 1) { Texto-Color $g 'SE BUSCA  ·  VIVO O MUERTO' 'EdmundMcMillen_INTLv4' 20 34 142 (C 255 236 205) (C 60 10 10) 4 }
            }
            if ($p -ge 62) { Texto-Color $g 'RECOMPENSA: 6 BALAS' 'EdmundMcMillen_INTLv4' 18 30 182 (C 255 214 120) (C 40 14 6) 5 }
        }
        # franjas de cine
        if ($barra -gt 0) {
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, [float]$barra)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, [float]($H - $barra), $W, [float]$barra)
            if ($p -ge 4 -and $p -lt 16) {
                $txt = 'EL DESIERTO.  LAS DOCE EN PUNTO.'; $txt = $txt.Substring(0, [Math]::Min($txt.Length, ($p - 4) * 3))
                $g.DrawString($txt, (FntP('EdmundMcMillen_INTLv4', 13)), (New-Object System.Drawing.SolidBrush((C 255 214 140))), 18, [float]($H - $barra + 12))
            }
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { Sonido 'viento' }
        if ($p -eq 18) { Sonido 'loco' }
        if ($p -eq 32) { Sonido 'grito' }
        if ($p -in @(40, 43, 46)) { Sonido 'bang'; [void]$script:agujeros.Add(@{ X = $Rnd.Next(60, 700); Y = $Rnd.Next(40, 260); R = $Rnd.Next(0, 40); P = $p }) }
        if ($p -eq 52) { Sonido 'recarga' }
        if ($p -gt 74) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 80 $pintar $alTick $final
}

# --- INSERT TOKEN: la ficha cae en la recreativa, el logo en llamas, cortes con las portadas oficiales y el cartel final ---
function Transicion-Token($final) {
    $script:tkPort = @(for ($i = 1; $i -le 8; $i++) { Cargar-Img "skins\token\portada$i.jpg" })
    $script:tkFuego = Cargar-Img $script:skin.Logo
    $script:iRecursos = @($script:tkPort) + @($script:tkFuego)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $rn = New-Object System.Random ($p * 31 + 7)
        if ($p -lt 12) {
            # 1) estática y "INSERT TOKEN"; la ficha cae por la ranura
            $g.Clear((C 6 4 6))
            for ($i = 0; $i -lt 260; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $rn.Next(40, 160) 255 255 255))), $rn.Next(0, $W), $rn.Next(0, $H), $rn.Next(1, 4), 1) }
            if ($p % 4 -lt 3) { Texto-Color $g 'INSERT TOKEN' 'Consolas' 34 ($W / 2 - 128) ($H / 2 - 64) (C 255 255 255) (C 230 20 40) 4 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 60 66))), ($W / 2 - 34), ($H / 2 + 34), 68, 10)
            $g.FillRectangle([System.Drawing.Brushes]::Black, ($W / 2 - 22), ($H / 2 + 37), 44, 4)
            if ($p -lt 9) {
                $cy = -30 + $p * (($H / 2 + 34) / 8.0)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 206 70))), [float]($W / 2 - 14), [float]$cy, 28, 28)
                $g.DrawEllipse((New-Object System.Drawing.Pen((C 160 110 20), 2)), [float]($W / 2 - 14), [float]$cy, 28, 28)
                Texto-Color $g 'T' 'Arial Black' 14 ($W / 2 - 6) ($cy + 4) (C 160 110 20) (C 255 230 140) 1
            }
            $cred = if ($p -ge 9) { 'CREDIT 01' } else { 'CREDIT 00' }
            $g.DrawString($cred, (FntP('Consolas', 12, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, ($W - 120), ($H - 28))
        } elseif ($p -lt 24) {
            # 2) el logo de femtanyl en llamas, temblando
            $g.Clear($(if ($p -in @(12, 13)) { (C 120 0 14) } else { (C 6 4 6) }))
            if ($script:tkFuego) {
                $e = [Math]::Max(1.0, 1.6 - ($p - 12) * 0.12)
                $lh = $H * 0.8 * $e; $lw = $script:tkFuego.Width * $lh / $script:tkFuego.Height
                $g.DrawImage($script:tkFuego, [float]($W / 2 - $lw / 2 + $rn.Next(-5, 6)), [float]($H / 2 - $lh / 2 + $rn.Next(-4, 5)), [float]$lw, [float]$lh)
            }
            for ($i = 0; $i -lt 5; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 230 20 40))), 0, $rn.Next(0, $H), $W, $rn.Next(1, 5)) }
        } elseif ($p -lt 52) {
            # 3) cortes rápidos: una portada oficial y una palabra cada pocos fotogramas
            $c = [int](($p - 24) / 3); $rc = New-Object System.Random ($c * 7 + 3)
            $g.Clear($(if ($c % 2 -eq 0) { (C 6 4 6) } else { (C 70 0 10) }))
            $im = $script:tkPort[$c % 8]
            if ($im) {
                $lado = 190 + $rc.Next(0, 70)
                $st = $g.Save(); $g.TranslateTransform([float]($W * 0.62 + $rc.Next(-60, 60)), [float]($H / 2 + $rc.Next(-20, 20))); $g.RotateTransform([float]$rc.Next(-9, 10))
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float](-$lado / 2 + 6), [float](-$lado / 2 + 6), [float]($lado + 12), [float]($lado + 12))
                $g.FillRectangle([System.Drawing.Brushes]::White, [float](-$lado / 2 - 6), [float](-$lado / 2 - 6), [float]($lado + 12), [float]($lado + 12))
                $g.DrawImage($im, [float](-$lado / 2), [float](-$lado / 2), [float]$lado, [float]$lado)
                $g.Restore($st)
            }
            $pal = $TokenCanciones[$c % 8]
            $st = $g.Save(); $g.TranslateTransform([float]$rc.Next(20, 120), [float]$rc.Next(50, [int]($H - 80))); $g.RotateTransform([float]$rc.Next(-10, 11))
            Texto-Color $g $pal 'Arial Black' (26 + $rc.Next(0, 12)) 0 0 (C 255 255 255) (C 230 20 40) 6
            $g.Restore($st)
            $sl = New-Object System.Drawing.Pen((ARGB 60 0 0 0), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($sl, 0, $y, $W, $y) }; $sl.Dispose()
        } else {
            # 4) cartel final: rayos rojos, la portada de AND IM GONE y su nombre
            $g.Clear((C 6 4 6))
            $cx = $W * 0.7; $cy = $H * 0.5; $rot = $p * 3
            $br = New-Object System.Drawing.SolidBrush((ARGB 90 230 20 40))
            for ($i = 0; $i -lt 14; $i++) {
                $a1 = [Math]::PI / 180 * ($rot + $i * 25.7 - 6); $a2 = [Math]::PI / 180 * ($rot + $i * 25.7 + 6)
                $g.FillPolygon($br, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$cx, [float]$cy)), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a1)), [float]($cy + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a2)), [float]($cy + 900 * [Math]::Sin($a2))))))
            }
            $br.Dispose()
            $im = $script:tkPort[0]
            if ($im) {
                $lado = $H * 0.78
                $st = $g.Save(); $g.TranslateTransform([float]$cx, [float]$cy); $g.RotateTransform(-4)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float](-$lado / 2 + 8), [float](-$lado / 2 + 8), [float]($lado + 14), [float]($lado + 14))
                $g.FillRectangle([System.Drawing.Brushes]::White, [float](-$lado / 2 - 7), [float](-$lado / 2 - 7), [float]($lado + 14), [float]($lado + 14))
                $g.DrawImage($im, [float](-$lado / 2 + $rn.Next(-2, 3)), [float](-$lado / 2), [float]$lado, [float]$lado)
                $g.Restore($st)
            }
            $t = [Math]::Min(1.0, ($p - 52) / 5.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            Texto-Color $g 'TOKEN' 'Arial Black' 78 (-380 + $e * 404) 56 (C 255 255 255) (C 230 20 40) 10
            if ($p -ge 56) { Texto-Color $g 'femtanyl' 'Consolas' 26 30 160 (C 255 60 70) (C 0 0 0) 4 }
            if ($p -ge 59) { Texto-Color $g 'T0K3N 1NS3RT3D' 'Consolas' 16 32 200 (C 255 255 255) (C 0 0 0) 3 }
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { Sonido 'glitch' }
        if ($p -eq 9) { Sonido 'moneda' }
        if ($p -eq 12) { Sonido 'golpe' }
        if ($p -eq 24) { Sonido 'breakcore' }
        if ($p -eq 52) { Sonido 'golpe' }
        if ($p -gt 68) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 74 $pintar $alTick $final
}
# --- cinta VHS: pantalla azul, PLAY, escenas del videoclip y el cartel de neón de "Pop Music" ---
# --- Tetra: la intro del videoclip de "You're Just Like Pop Music" (YonKaGor), sacada tal cual de YouTube: del título
#     "YOU'RE JUST LIKE POP MUSIC" hasta justo antes de la primera estrofa (segundos 3,8 a 24 del vídeo, sin el aviso
#     de epilepsia; el modo seguro ya quita las intros). El vídeo va en intro.gif y su audio en intro.mp3.
#     El reloj es el propio audio, para que imagen y sonido no se separen. Al acabar (o al saltarla) la
#     instrumental sigue por el mismo punto de la canción. ---
function Transicion-Pop($final) {
    $script:ppIntro = Cargar-Img $script:skin.IntroImg
    $script:ppInfo = if ($script:ppIntro) { Gif-Info $script:ppIntro } else { @{ N = 1; Del = @(100) } }
    $script:ppMs = 0; foreach ($d in $script:ppInfo.Del) { $script:ppMs += $d }
    $script:ppT0 = 0; $script:ppSaltar = $false; $script:ppAudio = $null; $script:ppFin = -1
    $script:iRecursos = @($script:ppIntro)
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $img = $script:ppIntro; if (-not $img) { return }
        $ms = Tetra-Intro-Ms
        Gif-Frame $img $script:ppInfo ([int][Math]::Max(0.0, [Math]::Min([double]$ms, [double]($script:ppMs - 1))))
        $g.InterpolationMode = 'HighQualityBilinear'
        # detrás, el mismo fotograma ampliado y oscurecido rellena los lados
        $sc = [Math]::Max([double]($W / $img.Width), [double]($H / $img.Height)); $cw = $img.Width * $sc; $ch = $img.Height * $sc
        $g.DrawImage($img, [float](($W - $cw) / 2), [float](($H - $ch) / 2), [float]$cw, [float]$ch)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 175 10 4 24))), 0, 0, $W, $H)
        # delante, el vídeo entero sin recortar
        $s = [Math]::Min([double]($W / $img.Width), [double]($H / $img.Height)); $vw = $img.Width * $s; $vh = $img.Height * $s
        $g.DrawImage($img, [float](($W - $vw) / 2), [float](($H - $vh) / 2), [float]$vw, [float]$vh)
        # entra desde negro y se funde a negro al final
        $a = 0.0
        if ($ms -lt 300) { $a = 1 - $ms / 300.0 }
        $resta = $script:ppMs - $ms; if ($resta -lt 400) { $a = 1 - $resta / 400.0 }
        $a = [Math]::Max(0.0, [Math]::Min(1.0, $a))
        if ($a -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $a)) 0 0 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        if ($script:ppSaltar -or (Tetra-Intro-Ms) -ge $script:ppMs) {
            Tetra-Intro-Terminar
            if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        }
    }
    # el vídeo y su audio arrancan a la vez
    $script:ppT0 = [Environment]::TickCount
    if ($script:aj.Sonido) {
        try {
            $mp = New-Object System.Windows.Media.MediaPlayer
            $mp.Open([Uri](Ruta $script:skin.IntroAudio)); $mp.Volume = (Tetra-Volumen); $mp.Play()
            $script:ppAudio = $mp
        } catch { $script:ppAudio = $null }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    $script:iOv.Add_MouseDown({ $script:ppSaltar = $true })
    $script:iOv.Cursor = 'Hand'
}
# milisegundos de intro: el audio manda; si no hay sonido (o aún no ha arrancado), el reloj del sistema
function Tetra-Intro-Ms {
    if ($script:ppT0 -le 0) { return 0 }
    $ms = [Environment]::TickCount - $script:ppT0
    if ($script:ppAudio) {
        try { $pa = $script:ppAudio.Position.TotalMilliseconds; if ($pa -gt 0) { $ms = $pa } } catch {}
    }
    return [double]$ms
}
# fin de la intro (o SALTAR): se calla el audio del vídeo y la instrumental sigue por donde iba el vídeo
function Tetra-Intro-Terminar {
    if ($script:ppFin -ge 0 -or $script:ppT0 -le 0) { return }
    $ms = [Math]::Min([double](Tetra-Intro-Ms), [double]$script:ppMs); $script:ppFin = $ms
    if ($script:ppAudio) { try { $script:ppAudio.Stop(); $script:ppAudio.Close() } catch {}; $script:ppAudio = $null }
    Tetra-Musica-Off; Tetra-Musica-On ([Math]::Max(0.0, [double]($ms + $TetraIntroDesde - $TetraDesfase)))
}
# --- Gran: la intro de su personaje en el vídeo de ANTIHUMAN (rayas grises, remolino de pintura, su cara y el busto
#     con la jeringuilla), tal cual, con su canción. Va por tiempo, no por fotogramas. Un clic la salta. ---
function Transicion-Gran($final) {
    $script:grIntro = Cargar-Img $script:skin.IntroImg
    $script:grIntroInfo = if ($script:grIntro) { Gif-Info $script:grIntro } else { @{ N = 1; Del = @(100) } }
    $script:grIntroMs = 0; foreach ($d in $script:grIntroInfo.Del) { $script:grIntroMs += $d }
    $script:grT0 = 0; $script:grSaltar = $false
    $script:iRecursos = @($script:grIntro)
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $img = $script:grIntro; if (-not $img) { return }
        $ms = if ($script:grT0 -gt 0) { [Environment]::TickCount - $script:grT0 } else { 0 }
        Gif-Frame $img $script:grIntroInfo ([Math]::Min($ms, $script:grIntroMs - 1))
        # el vídeo entero, sin recortar (bandas negras a los lados)
        $s = [Math]::Min($W / $img.Width, $H / $img.Height); $vw = $img.Width * $s; $vh = $img.Height * $s
        $g.InterpolationMode = 'HighQualityBilinear'
        $g.DrawImage($img, [float](($W - $vw) / 2), [float](($H - $vh) / 2), [float]$vw, [float]$vh)
        # se funde a negro al final
        $resta = $script:grIntroMs - $ms
        if ($resta -lt 400) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](255 * [Math]::Max(0.0, [Math]::Min(1.0, 1 - $resta / 400.0)))) 0 0 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { $script:grT0 = [Environment]::TickCount; Gran-Musica-On $true }
        $ms = [Environment]::TickCount - $script:grT0
        if ($script:grSaltar -or $ms -ge $script:grIntroMs) {
            if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    $script:iOv.Add_MouseDown({ $script:grSaltar = $true })
    $script:iOv.Cursor = 'Hand'
}
# --- Enfosi: la portada del juego, "conoce a tus Glaggles", uno se revela, el Ojo de Enphoso y la primera oleada ---
function Transicion-Enfosi($final) {
    $script:enIn = @{}
    foreach ($n in @('portada.jpg', 'logo.png', 'ojo.png', 'enphoso_titulo.png', 'giggler_oleada.png', 'gembo_enfosi.png')) { $script:enIn[$n] = Cargar-Img "skins\enfosi\$n" }
    foreach ($t in $EnfosiTipos) { $script:enIn[$t] = Cargar-Img "skins\enfosi\$t.png" }
    $script:iRecursos = @($script:enIn.Values)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $sx = 0; $sy = 0; if ($p -ge 44 -and $p -le 50) { $sx = $Rnd.Next(-8, 9); $sy = $Rnd.Next(-6, 7) }
        if ($p -lt 52) {
            # portada del juego (un Giggler con un arma y un Enphoso detrás), con un poco de zoom
            $z = 1 + $p * 0.002
            $im = $script:enIn['portada.jpg']
            if ($im) { Imagen-Cubrir $g $im (-$W * ($z - 1) / 2 + $sx) (-$H * ($z - 1) / 2 + $sy) ($W * $z) ($H * $z) 0.5 0.5 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $(if ($p -lt 14) { 90 } else { 170 }) 10 10 20))), 0, 0, $W, $H)
            # logo de los Glaggles que cae
            $lg = $script:enIn['logo.png']
            if ($lg) {
                $t = [Math]::Min(1.0, $p / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
                $lw = 300; $lh = $lg.Height * $lw / $lg.Width
                $g.DrawImage($lg, [float]($W / 2 - $lw / 2), [float](-$lh + $e * ($lh + 14)), [float]$lw, [float]$lh)
            }
            if ($p -ge 14) {
                # "conoce a tus Glaggles": van entrando en fila
                Texto-Color $g 'KNOW YOUR GLAGGLES!' 'Arial Black' 20 ($W / 2 - 132) 112 (C 255 255 255) (C 20 20 20) 5
                for ($i = 0; $i -lt 7; $i++) {
                    $t2 = [Math]::Min(1.0, [Math]::Max(0.0, ($p - 16 - $i * 2.5) / 6.0)); if ($t2 -le 0) { continue }
                    $e2 = 1 - [Math]::Pow(1 - $t2, 3)
                    $tipo = $EnfosiTipos[$i]
                    $im = if ($tipo -eq 'gembo' -and $p -ge 44) { $script:enIn['gembo_enfosi.png'] } else { $script:enIn[$tipo] }
                    if (-not $im) { continue }
                    $ih = 120; $iw = $im.Width * $ih / $im.Height
                    $x = 48 + $i * 96 + (1 - $e2) * ($W + 100); $y = $H - $ih - 30 + [Math]::Abs([Math]::Sin(($p + $i) * 0.5)) * -6
                    $g.DrawImage($im, [float]($x + $sx), [float]($y + $sy), [float]$iw, [float]$ih)
                }
                # uno de ellos era un Enphosian: explosión negra
                if ($p -ge 44 -and $p -lt 52) {
                    $q = $p - 44; $cx = 48 + 3 * 96 + 30; $cy = $H - 90
                    for ($k = 0; $k -lt 3; $k++) { $rr = 20 + $q * 14 + $k * 16; $g.DrawEllipse((New-Object System.Drawing.Pen((ARGB ([int](220 - $q * 25)) 0 0 0), 10)), [float]($cx - $rr), [float]($cy - $rr), [float](2 * $rr), [float](2 * $rr)) }
                    Texto-Color $g '¡ENPHOSIAN!' 'Arial Black' 30 ($cx - 110) ($cy - 150) (C 20 20 20) (C 255 255 255) 6
                }
            }
        } elseif ($p -lt 66) {
            # el Ojo de Enphoso
            $g.Clear((C 0 0 0))
            $q = $p - 52; $al = [Math]::Min(1.0, $q / 6.0)
            $oj = $script:enIn['ojo.png']
            if ($oj) {
                $sz = 180 + $q * 8
                $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$al
                $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                $g.DrawImage($oj, (New-Object System.Drawing.Rectangle([int]($W / 2 - $sz / 2), [int]($H / 2 - $sz / 2 + 10), [int]$sz, [int]$sz)), 0, 0, $oj.Width, $oj.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                $ia.Dispose()
            }
            $ti = $script:enIn['enphoso_titulo.png']
            if ($ti -and $q -ge 4) { $g.DrawImage($ti, [float]($W / 2 - 150), 14, 300, [float]($ti.Height * 300 / $ti.Width)) }
        } else {
            # primera oleada
            $im = $script:enIn['portada.jpg']; if ($im) { Imagen-Cubrir $g $im 0 0 $W $H 0.5 0.5 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 10 10 20))), 0, 0, $W, $H)
            $bn = $script:enIn['giggler_oleada.png']
            if ($bn) {
                $q = $p - 66; $e = if ($q -lt 4) { $q / 4.0 * 1.15 } elseif ($q -lt 7) { 1.15 - ($q - 4) / 3.0 * 0.15 } else { 1.0 }
                $bw = 420 * $e; $bh = $bn.Height * $bw / $bn.Width
                $g.DrawImage($bn, [float]($W / 2 - $bw / 2), [float]($H / 2 - $bh / 2 - 10), [float]$bw, [float]$bh)
            }
            Texto-Color $g 'OLEADA 1 / 7' 'Arial Black' 20 ($W / 2 - 80) ($H - 60) (C 255 255 255) (C 20 20 20) 5
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 2) { Sonido 'ding' }
        if ($p -eq 44) { Sonido 'revela' }
        if ($p -eq 52) { Sonido 'ojo' }
        if ($p -eq 66) { Sonido 'ola' }
        if ($p -gt 82) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 88 $pintar $alTick $final
}

# --- el templo de huesos, el ojo de la corona, el círculo ritual y la alianza del Cordero y la Cabra ---
function Transicion-Culto($final) {
    $script:tcFondo = Cargar-Img $script:skin.IntroImg
    $script:tcA = Cargar-Img $script:skin.Cartel; $script:tcB = Cargar-Img $script:skin.Cartel2
    $script:iRecursos = @($script:tcFondo, $script:tcA, $script:tcB)
    $script:tcLeyenda = '"Hay otro, viviendo más allá de tu reflejo... Ahora, joven dios. Te estaban esperando."'
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $g.Clear((C 10 4 6))
        # el templo aparece poco a poco desde la oscuridad, con un leve zoom
        if ($script:tcFondo) {
            $z = 1.12 - [Math]::Min(1.0, $p / 60.0) * 0.12
            $fw = $W * $z; $fh = $H * $z
            Imagen-Cubrir $g $script:tcFondo (($W - $fw) / 2) (($H - $fh) / 2) $fw $fh 0.5 0.4
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 - [Math]::Min(1.0, $p / 12.0) * 120), 10, 2, 4))), 0, 0, $W, $H)
        }
        $cx = $W / 2; $cy = 132
        # círculo ritual que se dibuja solo
        if ($p -ge 6) {
            $ang = [float][Math]::Min(360, ($p - 6) * 24)
            $pen = New-Object System.Drawing.Pen((C 220 40 54), 4)
            $g.DrawArc($pen, ($cx - 118), ($cy - 118), 236, 236, -90, $ang); $g.DrawArc($pen, ($cx - 104), ($cy - 104), 208, 208, 90, $ang)
            $pen.Dispose()
        }
        # el ojo rojo de la corona se abre
        $ab = [Math]::Min(1.0, $p / 10.0)
        if ($ab -gt 0) {
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 70 10 16))), [float]($cx - 64), [float]($cy - 38 * $ab), 128, [float](76 * $ab))
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 230 34 44))), [float]($cx - 24), [float]($cy - 24 * $ab), 48, [float](48 * $ab))
            $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($cx - 6), [float]($cy - 18 * $ab), 12, [float](36 * $ab))
        }
        # el Cordero entra por la izquierda y la Cabra por la derecha
        if ($p -ge 14) {
            $t = [Math]::Min(1.0, ($p - 14) / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            if ($script:tcA) { $g.DrawImage($script:tcA, [int](-220 + $e * 270), 34, 200, 188) }
            if ($script:tcB) { $g.DrawImage($script:tcB, [int]($W + 20 - $e * 270), 34, 200, 188) }
        }
        if ($p -ge 22) { Texto-Contorno $g 'EL CORDERO' 'Palatino Linotype' 30 40 214 (C 236 50 60) 7 }
        if ($p -ge 26) { Texto-Contorno $g 'LA CABRA' 'Palatino Linotype' 30 ($W - 210) 214 (C 186 126 236) 7 }
        if ($p -ge 30) { Texto-Contorno $g 'ALIANZA IMPÍA' 'Palatino Linotype' 26 ($cx - 112) 4 (C 238 226 200) 7 }
        if ($p -ge 34) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 0, 0, 0))), 0, ($H - 44), $W, 44)
            $n = [Math]::Min($script:tcLeyenda.Length, ($p - 34) * 4)
            $g.DrawString($script:tcLeyenda.Substring(0, $n), (FntP('Palatino Linotype', 10, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((C 210 170 240))), (New-Object System.Drawing.RectangleF(14, ($H - 40), ($W - 28), 38)))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'templo' }; if ($p -eq 4) { Sonido 'invocar' }; if ($p -eq 16) { Sonido 'balido' }; if ($p -eq 22) { Sonido 'enfado' }; if ($p -eq 30) { Sonido 'campana' }; if ($p -gt 62) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 68 $pintar $alTick $final
}

# --- la calle del pueblo: la radio avisa y las dos kaijus chocan ---
function Transicion-Kaiju($final) {
    $script:tkFondo = Cargar-Img $script:skin.IntroImg
    $script:tkA = Cargar-Img $script:skin.Cartel; $script:tkB = Cargar-Img $script:skin.Cartel2
    $script:iRecursos = @($script:tkFondo, $script:tkA, $script:tkB)
    $script:tkLeyenda = 'WMEW 99.9: "¡OH, DIOS! ¡EL LAGARTO DEL TRUENO SE ESTÁ PELEANDO CON LA TORTUGA ESPACIAL! ¡SALGAN DE AHÍ!"'
    $script:tkJp = Existe-Fuente 'Yu Gothic'
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $choque = 16
        $sx = 0; $sy = 0; if ($p -ge $choque -and $p -le $choque + 9) { $sx = $Rnd.Next(-9, 10); $sy = $Rnd.Next(-7, 8) }
        # la calle de la cinemática, temblando con el choque
        if ($script:tkFondo) { Imagen-Cubrir $g $script:tkFondo (-12 + $sx) (-8 + $sy) ($W + 24) ($H + 16) 0.5 0.6 } else { $g.Clear((C 60 50 50)) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 140, 50, 20))), 0, 0, $W, $H)
        # antes del choque: aviso de la radio
        if ($p -lt $choque) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))), 0, 0, $W, $H)
            if (($p % 6) -lt 4) { Texto-Contorno $g '¡ÚLTIMA HORA!' 'EdmundMcMillen_INTLv4' 34 ($W / 2 - 110) 24 (C 255 60 50) 7 }
        }
        # las dos entran a la carrera y chocan en el centro
        $t = [Math]::Min(1.0, $p / [double]$choque); $e = $t * $t
        if ($script:tkA) { $g.DrawImage($script:tkA, [int](-260 + $e * ($W / 2 - 10) + $sx), [int](34 + $sy), 216, 276) }
        if ($script:tkB) { $g.DrawImage($script:tkB, [int]($W + 20 - $e * ($W / 2 + 30) + $sx), [int](78 + $sy), 268, 236) }
        if ($p -ge $choque -and $p -lt $choque + 3) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 250, 230))), 0, 0, $W, $H) }
        # nubes de polvo del choque
        if ($p -ge $choque -and $p -lt $choque + 20) {
            $q = $p - $choque
            for ($i = 0; $i -lt 10; $i++) { $ang = $i * 36 * [Math]::PI / 180; $d = 20 + $q * 9; $s = 30 + $q * 3; $al = [Math]::Max(0, 200 - $q * 10)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 210, 200, 190))), [float]($W / 2 + [Math]::Cos($ang) * $d * 1.6 - $s / 2), [float](236 + [Math]::Sin($ang) * $d * 0.4 - $s / 2), [float]$s, [float]($s * 0.7)) }
        }
        if ($p -ge $choque + 2) {
            Texto-Contorno $g 'PYROPHINA' 'EdmundMcMillen_INTLv4' 46 16 6 (C 255 120 30) 8
            Texto-Contorno $g 'ZARATANA' 'EdmundMcMillen_INTLv4' 46 ($W - 20 - (Ancho-Texto 'ZARATANA' 'EdmundMcMillen_INTLv4' 46)) 6 (C 200 190 236) 8
            $tam = 84 + [Math]::Max(0, $choque + 8 - $p) * 7
            Texto-Contorno $g 'VS' 'EdmundMcMillen_INTLv4' $tam ($W / 2 - $tam * 0.42) (130 - $tam * 0.6) (C 255 214 60) 9
        }
        if ($p -ge $choque + 6 -and $script:tkJp) {
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString('ピロフィナ 対 ザラタナ', (FntP('Yu Gothic', 13, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 236 200))), (New-Object System.Drawing.RectangleF(0, 168, $W, 26)), $fmt)
        }
        if ($p -ge 30) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(225, 10, 8, 12))), 0, ($H - 54), $W, 54)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 200 40))), 0, ($H - 54), $W, 3)
            $n = [Math]::Min($script:tkLeyenda.Length, ($p - 30) * 5)
            $g.DrawString($script:tkLeyenda.Substring(0, $n), (FntP('TikaFont Adjusted', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 226 120))), (New-Object System.Drawing.RectangleF(14, ($H - 48), ($W - 28), 46)))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'radio' }; if ($p -eq 8) { Sonido 'pruge' }; if ($p -eq 12) { Sonido 'zruge' }; if ($p -eq 16) { Sonido 'pisoton' }; if ($p -gt 70) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 76 $pintar $alTick $final
}

# --- la polaroid de Averi cae entre hojas de otoño ---
function Transicion-Zorro($final) {
    $script:tzFoto = Cargar-Img 'skins\averi\feliz.png'
    $script:iRecursos = @($script:tzFoto)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear((C 255 240 220))
        # hojas de otoño cayendo
        $r = New-Object System.Random(4)
        for ($i = 0; $i -lt 18; $i++) {
            $x = $r.Next(0, $W); $v = 3 + $r.NextDouble() * 4; $y = (($r.Next(0, $H) + $p * $v) % ($H + 40)) - 20
            $col = @((C 230 128 56), (C 214 90 40), (C 240 180 70))[$i % 3]
            $st = $g.Save(); $g.TranslateTransform([float]($x + [Math]::Sin(($p + $i) / 4.0) * 10), [float]$y); $g.RotateTransform([float](($p * 8 + $i * 40) % 360))
            $g.FillEllipse((New-Object System.Drawing.SolidBrush($col)), -8, -4, 16, 8); $g.Restore($st)
        }
        # la foto cae y gira
        $t = [Math]::Min(1.0, $p / 12.0); $e = 1 - [Math]::Pow(1 - $t, 3)
        $st = $g.Save()
        $g.TranslateTransform([float]($W / 2), [float](-170 + $e * 310)); $g.RotateTransform([float](-20 + $e * 14))
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 60, 30, 10))), -104, -124, 220, 250)
        $g.FillRectangle([System.Drawing.Brushes]::White, -110, -130, 220, 250)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 226 190))), -96, -116, 192, 152)
        if ($script:tzFoto) { $g.DrawImage($script:tzFoto, -96, -116, 192, 152) }
        $g.DrawRectangle((New-Object System.Drawing.Pen((C 220 200 180), 1)), -110, -130, 220, 250)
        if ($p -ge 14) {
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString('¡Hola! Soy Averi', (FntP('Segoe Print', 13, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 110 60 30))), (New-Object System.Drawing.RectangleF(-108, 46, 216, 40)), $fmt)
        }
        $g.Restore($st)
        # el sándwich cae al lado, rebotando
        if ($p -ge 20) {
            $t2 = [Math]::Min(1.0, ($p - 20) / 8.0)
            $by = -40 + $t2 * 250 - [Math]::Abs([Math]::Sin($t2 * [Math]::PI * 2)) * 30 * (1 - $t2)
            Dibujar-Sandwich $g ($W / 2 + 170) $by 1.8
        }
        if ($p -ge 26) {
            for ($i = 0; $i -lt 5; $i++) { Dibujar-Corazon $g (($W / 2 - 200) + $i * 100) (240 - ($p - 26) * 5 - ($i % 2) * 24) 12 ([int][Math]::Max(0, 255 - ($p - 26) * 8)) }
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 8) { Sonido 'yip' }; if ($p -eq 26) { Sonido 'corazon' }; if ($p -eq 29) { Sonido 'comer' }; if ($p -gt 50) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 56 $pintar $alTick $final
}

# --- Sebastian: gateamos por la ventilación, se abre la rejilla y aparece su tienda ---
function Transicion-Vent($final) {
    $script:vFondo = Cargar-Img $script:skin.IntroImg
    $script:vTienda = Cargar-Img $script:skin.FondoImg
    $script:vSeb = Cargar-Img $script:skin.Gif
    $script:iRecursos = @($script:vFondo, $script:vTienda, $script:vSeb)
    $script:vLinea = 'SEBASTIAN: ' + (Azar $script:skin.Respiradero)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $cx = $W / 2; $cy = $H / 2
        if ($p -lt 34) {
            # dentro del conducto: avanzamos a gatas, con la linterna del casco
            $z = 1.0 + $p * 0.04; $bob = [Math]::Sin($p * 0.9) * 7
            if ($script:vFondo) { Imagen-Cubrir $g $script:vFondo (($W - $W * $z) / 2) ((($H - $H * $z) / 2) + $bob) ($W * $z) ($H * $z) 0.5 0.55 } else { $g.Clear((C 20 6 6)) }
            # paredes del conducto en perspectiva
            $m = New-Object System.Drawing.SolidBrush((ARGB 235 20 22 26)); $lin = New-Object System.Drawing.Pen((C 60 64 70), 3)
            $ix = 150 + ($p % 6) * 2; $iy = 70
            $g.FillPolygon($m, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.PointF($W, 0)), (New-Object System.Drawing.PointF(($W - $ix), $iy)), (New-Object System.Drawing.PointF($ix, $iy))))
            $g.FillPolygon($m, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, $H)), (New-Object System.Drawing.PointF($W, $H)), (New-Object System.Drawing.PointF(($W - $ix), ($H - $iy))), (New-Object System.Drawing.PointF($ix, ($H - $iy)))))
            foreach ($q in @(@(0, 0, $ix, $iy), @($W, 0, ($W - $ix), $iy), @(0, $H, $ix, ($H - $iy)), @($W, $H, ($W - $ix), ($H - $iy)))) { $g.DrawLine($lin, [float]$q[0], [float]$q[1], [float]$q[2], [float]$q[3]) }
            # remaches que pasan
            for ($i = 0; $i -lt 6; $i++) { $d = (($i * 0.17 + $p * 0.03) % 1.0); $rx = $ix * (1 - $d); $ry = $iy * (1 - $d); $g.DrawLine($lin, [float]$rx, [float]($H - $ry), [float]($W - $rx), [float]($H - $ry)) }
            $m.Dispose(); $lin.Dispose()
            # linterna: todo oscuro salvo un círculo de luz
            $mask = New-Object System.Drawing.Drawing2D.GraphicsPath; $mask.FillMode = 'Alternate'
            $mask.AddRectangle((New-Object System.Drawing.RectangleF(-10, -10, ($W + 20), ($H + 20)))); $mask.AddEllipse([float]($cx - 170), [float]($cy - 110 + $bob), 340, 220)
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 0 0 0))), $mask); $mask.Dispose()
            Texto-Contorno $g '*Gateando por la ventilación...*' 'Bahnschrift' 16 20 ($H - 34) (C 220 240 245) 3
        } else {
            # la tienda al otro lado
            if ($script:vTienda) { Imagen-Cubrir $g $script:vTienda 0 0 $W $H 0.0 0.45 } else { $g.Clear((C 8 10 14)) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 0 10 16))), 0, 0, $W, $H)
            # Sebastian se asoma desde la derecha
            if ($script:vSeb -and $p -ge 40) {
                $t = [Math]::Min(1.0, ($p - 40) / 10.0); $e = 1 - [Math]::Pow(1 - $t, 3)
                $sh = $H * 0.92; $sw = $script:vSeb.Width * $sh / $script:vSeb.Height
                $g.DrawImage($script:vSeb, [float]($W + 20 - $e * ($sw + 80)), [float]($H - $sh + 8 + [Math]::Sin($p / 3.0) * 3), [float]$sw, [float]$sh)
            }
            # la rejilla se abre hacia arriba
            if ($p -lt 46) {
                $sube = [Math]::Max(0, ($p - 36) * 34)
                $rej = New-Object System.Drawing.SolidBrush((C 50 54 60)); $bor = New-Object System.Drawing.Pen((C 22 24 28), 3)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 200 0 0 0))), 0, (0 - $sube), $W, $H)
                for ($y = 10; $y -lt $H; $y += 22) { $g.FillRectangle($rej, 30, ($y - $sube), ($W - 60), 12); $g.DrawRectangle($bor, 30, ($y - $sube), ($W - 60), 12) }
                $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 74 80), 10)), 20, (5 - $sube), ($W - 40), ($H - 10))
                $rej.Dispose(); $bor.Dispose()
            }
            if ($p -ge 48) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 215 4 6 8))), 30, ($H - 52), ($W - 60), 40)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 190 200))), 30, ($H - 52), 4, 40)
                $n = [Math]::Min($script:vLinea.Length, ($p - 48) * 3)
                $g.DrawString($script:vLinea.Substring(0, $n), (FntP('Bahnschrift', 12, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 235 245 248))), 44, ($H - 46))
            }
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'conducto' }; if ($p -eq 35) { Sonido 'rejilla' }; if ($p -gt 70) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 76 $pintar $alTick $final
}

# --- Pursuer: la animación de presentación del juego y su logo ---
function Transicion-DoD($final) {
    $script:dGif = Cargar-Img $script:skin.IntroImg
    $script:dLogo = Cargar-Img $script:skin.TituloImg
    $script:iRecursos = @($script:dGif, $script:dLogo)
    $script:dInfo = if ($script:dGif) { Gif-Info $script:dGif } else { @{ N = 1; Del = @(100) } }
    $script:dDur = 0; foreach ($d in $script:dInfo.Del) { $script:dDur += $d }
    $script:dFin = [int]([Math]::Min(4200, $script:dDur) / 45)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $g.Clear([System.Drawing.Color]::Black)
        if ($script:dGif) {
            # fotograma que toca según el tiempo
            $ms = [Math]::Min($p, $script:dFin) * 45; $acc = 0; $fr = 0
            for ($i = 0; $i -lt $script:dInfo.N; $i++) { $acc += $script:dInfo.Del[$i]; if ($acc -gt $ms) { $fr = $i; break }; $fr = $i }
            if ($script:dInfo.N -gt 1) { [void]$script:dGif.SelectActiveFrame((New-Object System.Drawing.Imaging.FrameDimension($script:dGif.FrameDimensionsList[0])), $fr) }
            Imagen-Cubrir $g $script:dGif 0 0 $W $H 0.5 0.5
        }
        # bandas de cine
        $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 26); $g.FillRectangle([System.Drawing.Brushes]::Black, 0, ($H - 26), $W, 26)
        if ($p -ge $script:dFin) {
            $q = $p - $script:dFin
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $q * 25), 0, 0, 0))), 0, 0, $W, $H)
            if ($script:dLogo) {
                $esc = [Math]::Max(1.0, 2.2 - $q * 0.25); $lw = 420 * $esc; $lh = $lw * $script:dLogo.Height / $script:dLogo.Width
                $sx = 0; if ($q -lt 6) { $sx = $Rnd.Next(-6, 7) }
                $g.DrawImage($script:dLogo, [float]($W / 2 - $lw / 2 + $sx), [float](80 - $lh / 2 + 30), [float]$lw, [float]$lh)
            }
            if ($q -ge 5) { Texto-Contorno $g '"AHH, FRESH MEAT!"' 'Arial Black' 30 ($W / 2 - (Ancho-Texto '"AHH, FRESH MEAT!"' 'Arial Black' 30) / 2) 200 (C 255 52 41) 6 }
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'intro' }; if ($p -eq $script:dFin) { Sonido 'aullido' }; if ($p -gt $script:dFin + 22) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay ($script:dFin + 28) $pintar $alTick $final
}

# --- Teto: montaje del videoclip de BIRDBRAIN (Teto bailando por la ciudad) y "¡Hiii~!" ---
function Transicion-Teto($final) {
    $script:tImg = Cargar-Img $script:skin.Gif
    $script:iRecursos = @($script:tImg)
    # bandada de palomas: cada una sale con un poco de retraso y a una altura distinta
    $r = New-Object System.Random 11
    $script:tBandada = @(for ($i = 0; $i -lt 16; $i++) { @{ D = $r.Next(0, 9); Y = 30 + $r.Next(0, 250); V = 46 + $r.Next(0, 18); E = 1.3 + $r.NextDouble() * 0.9; F = $r.NextDouble() * 6 } })
    $script:tPlumas = @(for ($i = 0; $i -lt 14; $i++) { @{ X = $r.Next(20, 740); D = 8 + $r.Next(0, 16); A = $r.Next(0, 360); V = 2 + $r.NextDouble() * 2 } })
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
        # fondo rosa con rayas que se mueven y franja de sus medias abajo
        Degradado $g 0 0 $W $H (C 253 228 232) (C 246 204 212) 90
        $ray = New-Object System.Drawing.Pen((ARGB 90 255 255 255), 16)
        for ($x = -$H - 60; $x -lt $W; $x += 46) { $g.DrawLine($ray, [float]($x + ($p * 2) % 46), 0, [float]($x + $H + ($p * 2) % 46), [float]$H) }
        $ray.Dispose()
        for ($x = 0; $x -lt $W; $x += 28) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 246 204 60))), $x, ($H - 16), 14, 16); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 252 232 150))), ($x + 14), ($H - 16), 14, 16) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 40 64))), 0, ($H - 20), $W, 4)
        # plumas cayendo después de la bandada
        if ($p -ge 10) {
            foreach ($f in $script:tPlumas) {
                $y = ($p - $f.D) * $f.V * 3 - 20; if ($y -lt -20 -or $y -gt $H) { continue }
                $st = $g.Save(); $g.TranslateTransform([float]($f.X + [Math]::Sin($p * 0.3 + $f.A) * 14), [float]$y); $g.RotateTransform([float]($f.A + $p * 6))
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 200 170 178 196))), -7, -2.5, 14, 5); $g.Restore($st)
            }
        }
        # Teto cae desde arriba y rebota al llegar
        $th = $H * 0.9; $tw = 0
        if ($script:tImg) {
            $tw = $script:tImg.Width * $th / $script:tImg.Height
            $t = [Math]::Max(0.0, [Math]::Min(1.0, ($p - 10) / 14.0))
            # rebote (easeOutBounce)
            if ($t -lt 1 / 2.75) { $e = 7.5625 * $t * $t } elseif ($t -lt 2 / 2.75) { $u = $t - 1.5 / 2.75; $e = 7.5625 * $u * $u + 0.75 } elseif ($t -lt 2.5 / 2.75) { $u = $t - 2.25 / 2.75; $e = 7.5625 * $u * $u + 0.9375 } else { $u = $t - 2.625 / 2.75; $e = 7.5625 * $u * $u + 0.984375 }
            $ty = ($H - $th - 12) - (1 - $e) * ($H + 40)
            $tx = $W * 0.66 - $tw / 2
            if ($p -ge 24) { $tx += [Math]::Sin($p * 0.35) * 5; $ty -= [Math]::Abs([Math]::Sin($p * 0.35)) * 6 }
            if ($p -ge 10) {
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int](60 * $e)) 150 20 40))), [float]($W * 0.66 - $tw * 0.45), [float]($H - 26), [float]($tw * 0.9), 12)
                $g.DrawImage($script:tImg, [float]$tx, [float]$ty, [float]$tw, [float]$th)
            }
            # estrellitas al aterrizar
            if ($p -ge 24 -and $p -lt 34) {
                $q = $p - 24
                foreach ($k in 0..5) { $ang = $k * 60 * [Math]::PI / 180; $rr = 30 + $q * 9; $sx = $W * 0.66 + [Math]::Cos($ang) * $rr; $sy = $H - 30 + [Math]::Sin($ang) * $rr * 0.4
                    Texto-Contorno $g '★' 'Segoe UI Symbol' 16 $sx $sy (C 255 214 60) 3 ([int](255 * (1 - $q / 10.0))) }
            }
        }
        # su nombre entra desde la izquierda: letras rojas con borde blanco grueso
        if ($p -ge 18) {
            $t = [Math]::Min(1.0, ($p - 18) / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            $nx = -420 + $e * 450
            foreach ($lin in @(@('KASANE', 58), @('TETO', 128))) {
                $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                $path.AddString($lin[0], (Familia 'Arial Black'), 0, 64, (New-Object System.Drawing.PointF([float]$nx, [float]$lin[1])), [System.Drawing.StringFormat]::GenericDefault)
                $m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(5, 6); $sombra = $path.Clone(); $sombra.Transform($m)
                $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 90 150 20 40))), $sombra)
                $pb = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 14); $pb.LineJoin = 'Round'; $g.DrawPath($pb, $path)
                $g.FillPath((New-Object System.Drawing.SolidBrush((C 214 40 64))), $path)
                $pb.Dispose(); $sombra.Dispose(); $path.Dispose()
            }
        }
        # pegatina amarilla de BIRDBRAIN
        if ($p -ge 30) {
            $q = $p - 30; $esc = if ($q -lt 3) { [Math]::Max(0.05, $q / 3.0 * 1.2) } elseif ($q -lt 6) { 1.2 - ($q - 3) / 3.0 * 0.2 } else { 1.0 }
            $st = $g.Save(); $g.TranslateTransform(150, 226); $g.RotateTransform(-6); $g.ScaleTransform([float]$esc, [float]$esc)
            $rp = Ruta-Redonda (-112) (-24) 224 48 24
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 255 255))), (Ruta-Redonda (-118) (-30) 236 60 30))
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 246 204 60))), $rp); $rp.Dispose()
            $tw2 = Ancho-Texto 'BIRDBRAIN' 'Arial Black' 26
            Texto-Contorno $g 'BIRDBRAIN' 'Arial Black' 26 (-$tw2 / 2) (-17) (C 176 24 48) 1
            $g.Restore($st)
        }
        # bocadillo "¡Hiii~!"
        if ($p -ge 26 -and $script:tImg) {
            $q = $p - 26; $esc = [Math]::Max(0.05, [Math]::Min(1.0, $q / 4.0))
            $bx = $W * 0.66 + $tw * 0.42; $by = 52
            $st = $g.Save(); $g.TranslateTransform([float]$bx, [float]$by); $g.ScaleTransform([float]$esc, [float]$esc)
            $rb = Ruta-Redonda 0 (-30) 150 60 26
            $g.FillPath([System.Drawing.Brushes]::White, $rb)
            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(16, 18)), (New-Object System.Drawing.PointF(-14, 38)), (New-Object System.Drawing.PointF(36, 24))))
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 40 64), 3)), $rb); $rb.Dispose()
            Texto-Contorno $g '¡Hiii~!' 'Arial Black' 26 16 (-17) (C 214 40 64) 1
            $g.Restore($st)
        }
        # la bandada cruza por delante
        foreach ($b in $script:tBandada) {
            $x = -80 + ($p - $b.D) * $b.V
            if ($x -lt -80 -or $x -gt $W + 80) { continue }
            Dibujar-Pajaro $g $x ($b.Y + [Math]::Sin($p * 0.5 + $b.F) * 8) $b.E $true ($p * 1.1 + $b.F) 1
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'pio' }; if ($p -eq 6) { Sonido 'pio' }; if ($p -eq 25) { Sonido 'hiii' }; if ($p -eq 40) { Sonido 'teto' }; if ($p -gt 78) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 84 $pintar $alTick $final
}

# --- Kevin: se abre Paint, se dibuja la pizza, "DON'T TOUCH MY PIZZA" palabra a palabra, fuego y su cartel ---
function Transicion-Pizza($final) {
    $script:kvCanta = Cargar-Img 'skins\kevin\canta.gif'; $script:kvFuego = Cargar-Img 'skins\kevin\fuego.gif'; $script:kvFeliz = Cargar-Img 'skins\kevin\feliz_t.gif'
    $script:kvInfo = @{ C = (Gif-Info $script:kvCanta); F = (Gif-Info $script:kvFuego); H = (Gif-Info $script:kvFeliz) }
    $script:iRecursos = @($script:kvCanta, $script:kvFuego, $script:kvFeliz)
    $r = New-Object System.Random 8
    $script:kvLluvia = @(for ($i = 0; $i -lt 18; $i++) { @{ X = $r.Next(0, 760); D = $r.Next(0, 30); V = 6 + $r.Next(0, 6); A = $r.Next(0, 360) } })
    $script:pzMusica = $null
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $ms = $p * 45
        if ($p -lt 16) {
            # 1) escritorio de Windows: se abre Paint y un lápiz dibuja la pizza
            $g.Clear((C 0 128 128))
            $e = [Math]::Min(1.0, ($p + 1) / 6.0); $e = 1 - [Math]::Pow(1 - $e, 3)
            $pw = 520 * $e; $ph = 250 * $e; $px = $W / 2 - $pw / 2; $py = $H / 2 - $ph / 2
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 212 208 200))), [float]$px, [float]$py, [float]$pw, [float]$ph)
            if ($e -gt 0.9) {
                Degradado $g $px $py $pw 20 (C 10 36 106) (C 166 202 240) 0
                $g.DrawString('kevin.png - Paint', (FntP('Tahoma', 9, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, [float]($px + 6), [float]($py + 3))
                $g.FillRectangle([System.Drawing.Brushes]::White, [float]($px + 6), [float]($py + 26), [float]($pw - 12), [float]($ph - 32))
                $cx = $W / 2; $cy = $py + 26 + ($ph - 32) / 2; $rr = 70
                $ang = [Math]::Min(360, [Math]::Max(0, ($p - 5) * 40))
                if ($ang -ge 360) {
                    Dibujar-Pizza $g $cx $cy $rr 8 $false
                } elseif ($ang -gt 0) {
                    $g.DrawArc((New-Object System.Drawing.Pen((C 20 20 20), 4)), [float]($cx - $rr), [float]($cy - $rr), [float](2 * $rr), [float](2 * $rr), -90, [float]$ang)
                    # el lápiz
                    $an = (-90 + $ang) * [Math]::PI / 180; $lx = $cx + [Math]::Cos($an) * $rr; $ly = $cy + [Math]::Sin($an) * $rr
                    $st = $g.Save(); $g.TranslateTransform([float]$lx, [float]$ly); $g.RotateTransform(-40)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 200 40))), 0, -5, 46, 10); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 140 160))), 46, -5, 10, 10)
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 240 210 160))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, -5)), (New-Object System.Drawing.PointF(0, 5)), (New-Object System.Drawing.PointF(-12, 0))))
                    $g.Restore($st)
                }
                $g.DrawString('nyanwolf presenta...', (FntP('Comic Sans MS', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 30 100 240))), [float]($px + 14), [float]($py + 30))
            }
        } elseif ($p -lt 48) {
            # 2) Kevin canta y las palabras caen de golpe: DON'T / TOUCH / MY / PIZZA
            $g.Clear([System.Drawing.Color]::White)
            foreach ($t in $script:kvLluvia) { $y = ($p - 16 - $t.D) * $t.V - 30; if ($y -gt -30 -and $y -lt $H + 30) { Dibujar-Trozo $g $t.X $y 26 ($t.A + $p * 9) } }
            if ($script:kvCanta) {
                Gif-Frame $script:kvCanta $script:kvInfo.C $ms
                $kh = $H * 0.98; $kw = $script:kvCanta.Width * $kh / $script:kvCanta.Height
                $g.DrawImage($script:kvCanta, [float]($W - $kw + 30), [float]($H - $kh), [float]$kw, [float]$kh)
            }
            $pal = @(@("DON'T", 18, (C 70 200 40)), @('TOUCH', 24, (C 30 100 240)), @('MY', 30, (C 255 110 200)), @('PIZZA', 36, (C 230 40 40)))
            $sx = 0; $sy = 0
            if ($p -lt 42 -and (($p - 18) % 6) -lt 2 -and $p -ge 18) { $sx = $Rnd.Next(-8, 9); $sy = $Rnd.Next(-6, 7) }
            for ($i = 0; $i -lt 4; $i++) {
                $q = $p - $pal[$i][1]; if ($q -lt 0) { continue }
                $esc = if ($q -lt 3) { 2.2 - $q * 0.4 } else { 1.0 }
                $st = $g.Save(); $g.TranslateTransform([float](40 + $sx + $i * 6), [float](30 + $i * 66 + $sy)); $g.RotateTransform(-4); $g.ScaleTransform([float]$esc, [float]$esc)
                Texto-Color $g $pal[$i][0] 'Impact' 56 0 0 $pal[$i][2] (C 20 20 20) 10
                $g.Restore($st)
            }
        } elseif ($p -lt 76) {
            # 3) ¡FUEGO! (lo que pasa si la tocas)
            $g.Clear((C 40 0 0))
            if ($script:kvFuego) {
                Gif-Frame $script:kvFuego $script:kvInfo.F (($p - 48) * 45)
                $s = [Math]::Max($W / $script:kvFuego.Width, $H / $script:kvFuego.Height) * 1.04
                $fw = $script:kvFuego.Width * $s; $fh = $script:kvFuego.Height * $s
                $g.DrawImage($script:kvFuego, [float]($W / 2 - $fw / 2 + $Rnd.Next(-4, 5)), [float]($H / 2 - $fh / 2 + $Rnd.Next(-4, 5)), [float]$fw, [float]$fh)
            }
            if ($p % 4 -lt 3) {
                $txt = '¡¡NO TOQUES MI PIZZA!!'; $tw = Ancho-Texto $txt 'Impact' 44
                Texto-Color $g $txt 'Impact' 44 ($W / 2 - $tw / 2 + $Rnd.Next(-3, 4)) ($H - 74) (C 255 230 60) (C 20 0 0) 9
            }
        } else {
            # 4) cartel final: arcoíris de 2010, Kevin feliz y su nombre letra a letra
            $g.Clear([System.Drawing.Color]::White)
            $arco = @((C 255 40 40), (C 255 150 30), (C 255 225 50), (C 90 210 80), (C 40 140 255), (C 140 70 220))
            for ($i = 0; $i -lt $arco.Count; $i++) {
                $pts = New-Object System.Collections.ArrayList
                for ($x = 0; $x -le $W; $x += 20) { [void]$pts.Add((New-Object System.Drawing.PointF([float]$x, [float](150 + $i * 16 + [Math]::Sin($x / 60.0 + $p * 0.5) * 8)))) }
                $g.DrawLines((New-Object System.Drawing.Pen($arco[$i], 16)), [System.Drawing.PointF[]]$pts.ToArray())
            }
            foreach ($t in $script:kvLluvia) { $a = $t.A + $p * 6; $rx = $W * 0.68 + [Math]::Cos(($t.A + $p * 5) * [Math]::PI / 180) * (150 + $t.D * 3); $ry = $H * 0.5 + [Math]::Sin(($t.A + $p * 5) * [Math]::PI / 180) * (90 + $t.D); Dibujar-Trozo $g $rx $ry 22 $a }
            if ($script:kvFeliz) {
                Gif-Frame $script:kvFeliz $script:kvInfo.H (($p - 76) * 45)
                $kh = $H * 0.95; $kw = $script:kvFeliz.Width * $kh / $script:kvFeliz.Height
                $kx = $W * 0.68 - $kw / 2
                $g.DrawImage($script:kvFeliz, [float]$kx, [float]($H - $kh), [float]$kw, [float]$kh)
            }
            $letras = 'KEVIN'.ToCharArray(); $cols = @((C 70 200 40), (C 30 100 240), (C 255 110 200), (C 255 206 84), (C 230 40 40))
            for ($i = 0; $i -lt $letras.Count; $i++) {
                $q = $p - 78 - $i * 2; if ($q -lt 0) { continue }
                $by = 40 - [Math]::Max(0, 30 - $q * 8) - [Math]::Abs([Math]::Sin(($p + $i) * 0.6)) * 6
                Texto-Color $g ([string]$letras[$i]) 'Comic Sans MS' 72 (30 + $i * 62) $by $cols[$i] (C 20 20 20) 10
            }
            if ($p -ge 90) { Texto-Color $g "don't touch my pizza  ·  nyanwolf" 'Comic Sans MS' 16 34 ($H - 56) (C 20 20 20) (C 255 255 255) 6 }
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) {
            if ($script:aj.Sonido) { $n = $script:reproductores.Count; Sonido 'polka'; if ($script:reproductores.Count -gt $n -or $script:reproductores.Count -ge 12) { $script:pzMusica = $script:reproductores[$script:reproductores.Count - 1] } }
        }
        if ($p -eq 18 -or $p -eq 24 -or $p -eq 30 -or $p -eq 36) { Sonido 'nam' }
        if ($p -eq 48) { Sonido 'grito' }
        if ($p -eq 76) { Sonido 'ding' }
        # la música se apaga poco a poco al final
        if ($p -ge 100 -and $script:pzMusica) { try { $script:pzMusica.Volume = $script:pzMusica.Volume * 0.72; if ($p -ge 111) { $script:pzMusica.Stop(); $script:pzMusica = $null } } catch {} }
        if ($p -gt 106) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 112 $pintar $alTick $final
}

# pastillas redondeadas y miniaturas de vídeo (estilo YouTube)
function Yt-Pastilla($g, $x, $y, $w, $h, $fondo, $texto, $colTexto, $tam) {
    $r = Ruta-Redonda $x $y $w $h ($h / 2)
    $g.FillPath((New-Object System.Drawing.SolidBrush($fondo)), $r); $r.Dispose()
    if ($texto) {
        $f = FntP('Segoe UI Symbol', $tam, [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($texto, $f).Width
        $g.DrawString($texto, $f, (New-Object System.Drawing.SolidBrush($colTexto)), [float]($x + $w / 2 - $tw / 2), [float]($y + $h / 2 - $f.Height / 2))
    }
}
# miniatura de vídeo: el GIF recortado, esquinas redondas y la duración abajo a la derecha
function Yt-Miniatura($g, $img, $inf, $ms, $x, $y, $w, $h, $dur) {
    if ($img) {
        Gif-Frame $img $inf $ms
        $st = $g.Save(); $rr = Ruta-Redonda $x $y $w $h 8; $g.SetClip($rr)
        $g.DrawImage($img, [float]$x, [float]$y, [float]$w, [float]$h)
        $g.Restore($st); $rr.Dispose()
    } else { $g.FillPath((New-Object System.Drawing.SolidBrush((C 39 39 39))), (Ruta-Redonda $x $y $w $h 8)) }
    if ($dur) {
        $f = FntP('Segoe UI', 6.5, [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($dur, $f).Width
        $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 210 0 0 0))), (Ruta-Redonda ($x + $w - $tw - 6) ($y + $h - 15) ($tw + 2) 12 3))
        $g.DrawString($dur, $f, [System.Drawing.Brushes]::White, [float]($x + $w - $tw - 5), [float]($y + $h - 15))
    }
}

# --- Kennyoung: su tablero de pegatinas. Se enciende el flexo y, al ritmo de Ready To Say, las escenas de sus
#     vídeos se pegan una a una en la pared (los cuadros de su camisa); al final él mismo se pega en el centro con su nombre ---
# Va sincronizada con la canción: el reloj es la posición del audio. Momentos (ms desde el principio de la canción),
# puestos en sus golpes (un compás dura unos 2760 ms). La canción sigue sonando después en su escena.
$KyIntro = @{ Flexo = 700; Luz = 860; Kenny = 7300; Nombre = 7640; Fin = 10400
    Pegatinas = @(
        @{ Esc = 'animado'; T = 1960; X = 0.15; Y = 0.24; Rot = -9.0 },
        @{ Esc = 'tranquilo'; T = 2820; X = 0.85; Y = 0.25; Rot = 7.0 },
        @{ Esc = 'solo'; T = 3340; X = 0.18; Y = 0.73; Rot = 5.0 },
        @{ Esc = 'cansado'; T = 4540; X = 0.83; Y = 0.74; Rot = -6.0 },
        @{ Esc = 'agobiado'; T = 5580; X = 0.31; Y = 0.47; Rot = -13.0 }
    )
    Palabras = @(
        @{ Txt = 'MUSIC'; T = 8340; Col = @(255, 110, 170); Rot = -6.0 },
        @{ Txt = 'ART'; T = 8860; Col = @(110, 235, 140); Rot = 4.0 },
        @{ Txt = 'VIDEO'; T = 9020; Col = @(255, 236, 200); Rot = -3.0 }
    ) }
# el reloj de la intro: la posición de la canción (si aún no suena, espera hasta 1,5 s)
function Ky-Intro-Ms {
    if ($script:kyT0 -le 0) { return 0.0 }
    $t = [double]([Environment]::TickCount - $script:kyT0)
    if ($script:kyMusica) {
        try { $pos = $script:kyMusica.Position.TotalMilliseconds; if ($pos -gt 30) { $t = $pos } elseif ($t -lt 1500) { $t = 0.0 } } catch {}
    }
    return $t
}
# copia un dibujo con su sombra (su silueta en negro, desplazada)
function Ky-Con-Sombra($bmp, $dx, $dy, $alfa) {
    $m = 4 + [Math]::Max([Math]::Abs($dx), [Math]::Abs($dy))
    $out = New-Object System.Drawing.Bitmap(($bmp.Width + 2 * $m), ($bmp.Height + 2 * $m))
    $g = [System.Drawing.Graphics]::FromImage($out); $g.InterpolationMode = 'HighQualityBilinear'
    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix00 = 0; $cm.Matrix11 = 0; $cm.Matrix22 = 0; $cm.Matrix33 = [float]$alfa
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(($m + $dx), ($m + $dy), $bmp.Width, $bmp.Height)), 0, 0, $bmp.Width, $bmp.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.DrawImage($bmp, $m, $m, $bmp.Width, $bmp.Height)
    $ia.Dispose(); $g.Dispose(); $bmp.Dispose()
    return $out
}
# una escena de sus vídeos hecha pegatina: borde verde en zigzag y una etiqueta escrita a mano
function Ky-Pegatina-Escena($img, $w, $h, $texto) {
    $m = 12; $bmp = New-Object System.Drawing.Bitmap([int]($w + 2 * $m), [int]($h + 2 * $m + 6))
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
    Dibujar-Pegatina $g $m $m $w $h ([System.Drawing.Color]::White)
    $r = Ruta-Redonda ($m + 4) ($m + 4) ($w - 8) ($h - 8) 7
    if ($img) { $g.SetClip($r); $g.DrawImage($img, [float]($m + 4), [float]($m + 4), [float]($w - 8), [float]($h - 8)); $g.ResetClip() }
    $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 1.5)), $r); $r.Dispose()
    $f = FntP('Segoe Print', 7.5, [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($texto, $f).Width
    $et = Ruta-Redonda ($m + 8) ($m + $h - 16) ($tw + 8) 20 6
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 250 240))), $et); $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 1.5)), $et); $et.Dispose()
    $g.DrawString($texto, $f, (New-Object System.Drawing.SolidBrush((C 70 50 45))), [float]($m + 12), [float]($m + $h - 17))
    $g.Dispose()
    return (Ky-Con-Sombra $bmp 4 5 0.35)
}
# él recortado, con un borde verde gordo de pegatina
function Ky-Pegatina-Recorte($img, $h) {
    $w = [int]($img.Width * $h / $img.Height); $h = [int]$h; $m = 10
    $bmp = New-Object System.Drawing.Bitmap(($w + 2 * $m), ($h + 2 * $m))
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBilinear'
    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix00 = 0; $cm.Matrix11 = 0; $cm.Matrix22 = 0
    $cm.Matrix40 = [float](110 / 255.0); $cm.Matrix41 = [float](235 / 255.0); $cm.Matrix42 = [float](140 / 255.0)
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    for ($i = 0; $i -lt 16; $i++) {
        $an = $i * [Math]::PI / 8; $ox = [int]([Math]::Cos($an) * 7); $oy = [int]([Math]::Sin($an) * 7)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle(($m + $ox), ($m + $oy), $w, $h)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    }
    $g.DrawImage($img, $m, $m, $w, $h)
    $ia.Dispose(); $g.Dispose()
    return (Ky-Con-Sombra $bmp 5 6 0.35)
}
# su nombre como pegatina: letras crema, contorno oscuro y borde verde
function Ky-Pegatina-Nombre($txt, $tam) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia 'Arial Black'), 0, [float]$tam, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericTypographic)
    $bb = $path.GetBounds(); $m = 14
    $bmp = New-Object System.Drawing.Bitmap([int]($bb.Width + 2 * $m), [int]($bb.Height + 2 * $m))
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $g.TranslateTransform([float]($m - $bb.X), [float]($m - $bb.Y))
    foreach ($pp in @(@(16, (C 110 235 140)), @(5, (C 70 50 45)))) { $pn = New-Object System.Drawing.Pen($pp[1], [float]$pp[0]); $pn.LineJoin = 'Round'; $g.DrawPath($pn, $path); $pn.Dispose() }
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 244 246))), $path)
    $path.Dispose(); $g.Dispose()
    return (Ky-Con-Sombra $bmp 4 5 0.35)
}
# una etiqueta de papel con una palabra
function Ky-Etiqueta($txt, $col) {
    $f = FntP('Arial Black', 11); $tmp = New-Object System.Drawing.Bitmap(1, 1); $gt = [System.Drawing.Graphics]::FromImage($tmp)
    $tw = [int]$gt.MeasureString($txt, $f).Width; $gt.Dispose(); $tmp.Dispose()
    $bmp = New-Object System.Drawing.Bitmap(($tw + 22), 34)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $r = Ruta-Redonda 2 2 ($tw + 16) 28 6
    $g.FillPath((New-Object System.Drawing.SolidBrush((C $col[0] $col[1] $col[2]))), $r); $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 2)), $r); $r.Dispose()
    $g.DrawString($txt, $f, (New-Object System.Drawing.SolidBrush((C 46 34 30))), 9, 6)
    $g.Dispose()
    return (Ky-Con-Sombra $bmp 3 4 0.35)
}
# dibuja una pegatina que cae y se pega en (cx, cy) justo en el momento t0 (y rebota un poco)
function Ky-Pegar($g, $bmp, $cx, $cy, $rot, $ms, $t0, $escala) {
    $d = $ms - $t0; if ($d -lt -140 -or -not $bmp) { return }
    if ($d -lt 0) { $q = - $d / 140.0; $s = 1 + 0.9 * $q * $q; $al = 1 - 0.75 * $q; $rot = $rot - 18 * $q }
    else { $s = 1 + 0.06 * [Math]::Sin($d / 28.0) * [Math]::Exp(- $d / 90.0); $al = 1.0 }
    $s = $s * $escala
    $st = $g.Save(); $g.TranslateTransform([float]$cx, [float]$cy); $g.RotateTransform([float]$rot); $g.ScaleTransform([float]$s, [float]$s)
    $w = $bmp.Width; $h = $bmp.Height
    if ($al -ge 0.999) { $g.DrawImage($bmp, [float](- $w / 2), [float](- $h / 2), [float]$w, [float]$h) }
    else {
        $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$al
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle([int](- $w / 2), [int](- $h / 2), $w, $h)), 0, 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel, $ia); $ia.Dispose()
    }
    $g.Restore($st)
}
# chispas de colores que salen al pegar
function Ky-Chispas($g, $cx, $cy, $d, $n, $rad) {
    if ($d -lt 0 -or $d -gt 520) { return }
    $q = $d / 520.0; $al = [int](230 * (1 - $q)); $avance = 1 - [Math]::Pow(1 - $q, 3)
    for ($i = 0; $i -lt $n; $i++) {
        $an = $i * 2 * [Math]::PI / $n + 0.4; $r = $rad + 46 * $avance
        $x = $cx + [Math]::Cos($an) * $r * 1.5; $y = $cy + [Math]::Sin($an) * $r
        $col = switch ($i % 3) { 0 { [System.Drawing.Color]::FromArgb($al, 255, 110, 170) } 1 { [System.Drawing.Color]::FromArgb($al, 110, 235, 140) } default { [System.Drawing.Color]::FromArgb($al, 255, 244, 200) } }
        $sz = 7 * (1 - $q) + 2
        $b = New-Object System.Drawing.SolidBrush($col); $g.FillEllipse($b, [float]($x - $sz / 2), [float]($y - $sz / 2), [float]$sz, [float]$sz); $b.Dispose()
    }
}
# la luz del flexo: un círculo de luz cálida que se balancea; fuera, la habitación a oscuras
function Ky-Flexo($g, $W, $H, $ms, $oscuro) {
    $cx = $W * 0.5 + [Math]::Sin($ms / 900.0) * 18; $cy = $H * 0.12; $rx = $W * 0.62; $ry = $H * 0.95
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($cx - $rx), [float]($cy - $ry), [float](2 * $rx), [float](2 * $ry))
    $modo = $g.SmoothingMode; $g.SmoothingMode = 'None'   # sin suavizado: así no quedan rayas en el borde de la luz
    $rg = New-Object System.Drawing.Region((New-Object System.Drawing.RectangleF(-20, -20, ($W + 40), ($H + 40)))); $rg.Exclude($gp)
    $g.FillRegion((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($oscuro, 12, 8, 10))), $rg); $rg.Dispose()
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pg.CenterPoint = New-Object System.Drawing.PointF([float]$cx, [float]$cy)
    $pg.CenterColor = [System.Drawing.Color]::FromArgb(0, 255, 210, 150); $pg.SurroundColors = @([System.Drawing.Color]::FromArgb($oscuro, 12, 8, 10))
    $pg.FocusScales = New-Object System.Drawing.PointF(0.35, 0.35)
    $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose(); $g.SmoothingMode = $modo
    # la lámpara colgando del techo
    $g.DrawLine((New-Object System.Drawing.Pen((C 40 30 28), 2)), [float]$cx, 0, [float]$cx, 14)
    $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($cx - 9), 13)), (New-Object System.Drawing.PointF([float]($cx + 9), 13)), (New-Object System.Drawing.PointF([float]($cx + 24), 31)), (New-Object System.Drawing.PointF([float]($cx - 24), 31)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 110 235 140))), $pts); $g.DrawPolygon((New-Object System.Drawing.Pen((C 46 34 30), 2)), $pts)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 246 210))), [float]($cx - 8), 26, 16, 10)
}
function Transicion-Punk($final) {
    $W0 = [int]($form.ClientSize.Width / $script:K); $H0 = [int]($form.ClientSize.Height / $script:K); $T = $KyIntro
    # todo se prepara antes: la pared, las pegatinas, él y su nombre
    $script:kiPared = New-Object System.Drawing.Bitmap(($W0 + 24), ($H0 + 24))
    $gp = [System.Drawing.Graphics]::FromImage($script:kiPared); Dibujar-Cuadros $gp 0 0 ($W0 + 24) ($H0 + 24); $gp.Dispose()
    $pw = [int]($W0 * 0.2); $ph = [int]($pw * 444 / 712)
    $script:kiPeg = @(foreach ($pg in $T.Pegatinas) { Ky-Pegatina-Escena (Ky-Img $pg.Esc) $pw $ph $KyEscenas[$pg.Esc].Nombre })
    $ik = Cargar-Img 'skins\kennyoung\intro_kenny.png'
    $script:kiKenny = if ($ik) { Ky-Pegatina-Recorte $ik ($H0 * 0.86) } else { $null }
    if ($ik) { $ik.Dispose() }
    $script:kiNombre = Ky-Pegatina-Nombre 'KENNYOUNG' (50 * $W0 / 760.0)
    $script:kiPal = @(foreach ($pl in $T.Palabras) { Ky-Etiqueta $pl.Txt $pl.Col })
    $script:iRecursos = @($script:kiPared, $script:kiKenny, $script:kiNombre) + $script:kiPeg + $script:kiPal
    # los sonidos: el clic del flexo y un golpe por cada pegatina
    $ev = New-Object System.Collections.ArrayList
    [void]$ev.Add(@{ T = $T.Flexo; Id = 'flexo'; Son = 'flexo' })
    $i = 0; foreach ($pg in $T.Pegatinas) { [void]$ev.Add(@{ T = $pg.T; Id = "p$i"; Son = 'pegar' }); $i++ }
    [void]$ev.Add(@{ T = $T.Kenny; Id = 'kenny'; Son = 'pegar' }); [void]$ev.Add(@{ T = $T.Nombre; Id = 'nombre'; Son = 'pegar' })
    $i = 0; foreach ($pl in $T.Palabras) { [void]$ev.Add(@{ T = $pl.T; Id = "w$i"; Son = 'pegar' }); $i++ }
    $script:kiEventos = $ev.ToArray()
    $script:kyT0 = 0; $script:kyHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $T = $KyIntro; $ms = Ky-Intro-Ms
        $g.Clear([System.Drawing.Color]::Black)
        if ($ms -lt $T.Flexo -or ($ms -ge $T.Flexo + 60 -and $ms -lt $T.Luz)) { return }   # a oscuras (y el parpadeo al encender)
        # la pared tiembla un poco con cada golpe
        $sh = 0.0
        foreach ($e in $script:kiEventos) {
            $d = $ms - $e.T
            if ($e.Id -ne 'flexo' -and $d -ge 0 -and $d -lt 160) { $amp = if ($e.Id -eq 'kenny') { 9 } else { 3.5 }; $sh += $amp * (1 - $d / 160.0) * [Math]::Sin($d / 14.0) }
        }
        $st0 = $g.Save(); $g.TranslateTransform([float]$sh, [float]($sh * 0.5))
        $g.DrawImage($script:kiPared, -12, -12, ($W + 24), ($H + 24))
        # 1) las escenas de sus vídeos, una por golpe
        for ($i = 0; $i -lt $T.Pegatinas.Count; $i++) {
            $pg = $T.Pegatinas[$i]; $cx = $W * $pg.X; $cy = $H * $pg.Y
            Ky-Pegar $g $script:kiPeg[$i] $cx $cy $pg.Rot $ms $pg.T 1.0
            Ky-Chispas $g $cx $cy ($ms - $pg.T) 8 ($script:kiPeg[$i].Height * 0.42)
        }
        # 2) él, en el centro, que late con la música
        if ($script:kiKenny) {
            $kd = $ms - $T.Kenny; $pulso = 1.0
            if ($kd -gt 300) { $pulso = 1 + 0.02 * [Math]::Exp(- (($kd % 690) / 110.0)) }
            Ky-Pegar $g $script:kiKenny ($W * 0.5) ($H - $script:kiKenny.Height / 2 + 14) 0.0 $ms $T.Kenny $pulso
            Ky-Chispas $g ($W * 0.5) ($H * 0.5) $kd 14 ($H * 0.36)
        }
        # 3) su nombre y MUSIC · ART · VIDEO
        Ky-Pegar $g $script:kiNombre ($W * 0.5) ($H * 0.79) -4.0 $ms $T.Nombre 1.0
        for ($i = 0; $i -lt $T.Palabras.Count; $i++) {
            $pl = $T.Palabras[$i]
            Ky-Pegar $g $script:kiPal[$i] ($W * 0.5 + ($i - 1) * 86) ($H * 0.93) $pl.Rot $ms $pl.T 1.0
        }
        $g.Restore($st0)
        # la luz del flexo (al pegarse él, la habitación se ilumina más)
        $osc = 225
        if ($ms -ge $T.Kenny) { $osc = [int](225 - 95 * [Math]::Min(1.0, ($ms - $T.Kenny) / 400.0)) }
        Ky-Flexo $g $W $H $ms $osc
        # un destello al pegarse él
        $fd = $ms - $T.Kenny
        if ($fd -ge 0 -and $fd -lt 220 -and -not $script:aj.Epilepsia) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](150 * (1 - $fd / 220.0)), 255, 255, 255))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $T = $KyIntro
        if ($p -eq 1) { $script:kyT0 = [Environment]::TickCount; Ky-Reset; Ky-Poner-Musica 'readytosay' 0 }
        $ms = Ky-Intro-Ms
        foreach ($ev in $script:kiEventos) {
            if ($ms -ge $ev.T - 30 -and -not $script:kyHechos.ContainsKey($ev.Id)) { $script:kyHechos[$ev.Id] = $true; Sonido $ev.Son }
        }
        if ($ms -gt $T.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Evil Scary: la pantalla de la RONDA ESPECIAL del juego ("SPECIAL ROUND! ???" -> "EVIL SCARY"),
#     luego "IT IS EVIL AND SCARY" y la bola negra botando hacia la cámara hasta el susto ---
# Va sincronizada con el reloj. Momentos (en milisegundos):
$EsIntro = @{ Ruleta = 400; Revela = 2600; Mensaje = 5200; Bote1 = 6600; Bote2 = 7400; Bote3 = 8200; Susto = 9000; Fin = 10300 }
# el cartel de "SPECIAL ROUND!" de Die of Death: caja oscura con borde rojo y tres líneas de texto
function Dibujar-Ronda($g, $W, $H, $grande, $abajo, $colGrande, $esc) {
    $bw = 470 * $esc; $bh = 150 * $esc; $bx = $W / 2 - $bw / 2; $by = $H / 2 - $bh / 2 - 10
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 235 24 18 18))), [float]$bx, [float]$by, [float]$bw, [float]$bh)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 170 20 30), [float](3 * $esc))), [float]$bx, [float]$by, [float]$bw, [float]$bh)
    $fm = New-Object System.Drawing.StringFormat; $fm.Alignment = 'Center'
    $g.DrawString('SPECIAL ROUND!', (FntP('Arial', [float](17 * $esc), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 120 20 26))), (New-Object System.Drawing.RectangleF([float]$bx, [float]($by + 8 * $esc), [float]$bw, [float](30 * $esc))), $fm)
    $g.DrawString($grande, (FntP('Arial', [float](34 * $esc), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($colGrande)), (New-Object System.Drawing.RectangleF([float]$bx, [float]($by + 38 * $esc), [float]$bw, [float](60 * $esc))), $fm)
    $g.DrawString($abajo, (FntP('Arial', [float](10.5 * $esc), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 200 200 200))), (New-Object System.Drawing.RectangleF([float]$bx, [float]($by + 104 * $esc), [float]$bw, [float](40 * $esc))), $fm)
}
function Transicion-Evil($final) {
    $k = $script:skin
    $script:eiFondo = Cargar-Img $k.FondoImg; $script:eiSusto = Cargar-Img $k.Susto; $script:eiEvil = Cargar-Img $k.Gif
    $script:iRecursos = @($script:eiFondo, $script:eiSusto, $script:eiEvil)
    $script:eiT0 = 0; $script:eiHechos = @{}
    $script:eiModos = @('???', 'ONE BOUNCE', 'GUNSLINGER', 'DOUBLE TROUBLE', 'DIENATION', '???', 'GOLF', 'FRYBOMBER')
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
        $T = $EsIntro
        $ms = if ($script:eiT0 -gt 0) { [Environment]::TickCount - $script:eiT0 } else { 0 }
        $g.Clear([System.Drawing.Color]::Black)
        if ($ms -lt $T.Mensaje) {
            # 1) el mapa de fondo, muy oscuro, y el cartel de la ronda especial
            if ($script:eiFondo) {
                [void](Dibujar-Cubriendo $g $script:eiFondo $W $H 1.05 0.5 0.5)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 0 0 0))), 0, 0, $W, $H)
            }
            $esc = [Math]::Min(1.0, 0.6 + $ms / 600.0)
            if ($ms -lt $T.Revela) {
                # "???" y una ruleta de modos que va frenando
                $txt = if ($ms -lt $T.Ruleta) { '???' } else { $i = [int](($ms - $T.Ruleta) / (70 + ($ms - $T.Ruleta) / 18.0)); $script:eiModos[$i % $script:eiModos.Count] }
                Dibujar-Ronda $g $W $H $txt 'What will it be?' (C 170 170 170) $esc
            } else {
                $q = [Math]::Min(1.0, ($ms - $T.Revela) / 250.0); $e2 = 1.25 - 0.25 * $q
                Dibujar-Ronda $g $W $H 'EVIL SCARY' 'The Evil Scary will eradicate anything in its path.' (C 150 20 28) $e2
            }
        } elseif ($ms -lt $T.Susto) {
            # 2) negro. "IT IS EVIL AND SCARY" y la bola negra botando hacia la cámara
            if ($script:eiFondo) { [void](Dibujar-Cubriendo $g $script:eiFondo $W $H 1.1 0.5 0.5); $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 200 0 0 0))), 0, 0, $W, $H) }
            $q = [Math]::Min(1.0, ($ms - $T.Mensaje) / 400.0)
            $fm = New-Object System.Drawing.StringFormat; $fm.Alignment = 'Center'
            $g.DrawString('IT IS EVIL AND SCARY', (FntP('Arial', 26, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * $q), 220, 30, 40))), (New-Object System.Drawing.RectangleF(0, 30, $W, 50)), $fm)
            if ($script:eiEvil -and $ms -ge $T.Bote1) {
                $n = if ($ms -ge $T.Bote3) { 3 } elseif ($ms -ge $T.Bote2) { 2 } else { 1 }
                $t0 = @($T.Bote1, $T.Bote2, $T.Bote3)[$n - 1]
                $salto = [Math]::Sin([Math]::Min(1.0, ($ms - $t0) / 250.0) * [Math]::PI) * 18
                $ew = @(140, 260, 470)[$n - 1]; $eh = $ew * $script:eiEvil.Height / $script:eiEvil.Width
                $g.DrawImage($script:eiEvil, [float]($W / 2 - $ew / 2), [float]($H * 0.62 + $n * 25 - $eh - $salto), [float]$ew, [float]$eh)
            }
        } else {
            # 3) el susto (cara roja a toda pantalla, que se apaga)
            if ($script:eiSusto) {
                $q = [Math]::Min(1.0, ($ms - $T.Susto) / 1200.0)
                [void](Dibujar-Cubriendo $g $script:eiSusto $W $H (1.0 + $q * 0.2) 0.5 0.5)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * $q), 0, 0, 0))), 0, 0, $W, $H)
            }
        }
    }
    $alTick = {
        param($ov, $p)
        $T = $EsIntro
        if ($p -eq 1) { $script:eiT0 = [Environment]::TickCount }
        $ms = [Environment]::TickCount - $script:eiT0
        foreach ($ev in @(@($T.Revela, 'violin'), @($T.Mensaje, 'susto'), @($T.Bote1, 'lejos'), @($T.Bote2, 'medio'), @($T.Bote3, 'cerca'), @($T.Susto, 'grito'))) {
            if ($ms -ge $ev[0] -and -not $script:eiHechos.ContainsKey($ev[1])) { $script:eiHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $T.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Soft Fuzzy Man: el principio de la animación de Aimkid (con su audio) hasta que la espiral rosa llena la pantalla
#     (12,2 s, justo antes del cambio de escena); de ahí la niebla rosa lo tapa todo y el panel sale de la niebla ---
# Los fotogramas están en skins\softfuzzy\intro (001.jpg, 002.jpg...), a 18 por segundo. Momentos (en milisegundos):
$SfIntro = @{ Niebla = 12000; Fin = 13600 }
function Transicion-Fuzzy($final) {
    $script:fiImg = $null; $script:fiIdx = -1; $script:fiT0 = 0; $script:iRecursos = @()
    Sf-Reset
    $pintar = {
        param($g, $W, $H, $p)
        $g.InterpolationMode = 'HighQualityBilinear'; $g.SmoothingMode = 'AntiAlias'
        $k = $script:skin; $T = $SfIntro
        $ms = if ($script:fiT0 -gt 0) { [Environment]::TickCount - $script:fiT0 } else { 0 }
        $g.Clear((C 82 31 135))
        # el fotograma que toca según el reloj (se carga solo el que hace falta)
        $idx = [Math]::Min($k.IntroFotos - 1, [int][Math]::Floor($ms * $k.IntroFps / 1000.0))
        if ($idx -ne $script:fiIdx) {
            $nueva = Cargar-Img ('{0}\{1:000}.jpg' -f $k.IntroCarpeta, ($idx + 1))
            if ($nueva) { if ($script:fiImg) { $script:fiImg.Dispose() }; $script:fiImg = $nueva; $script:fiIdx = $idx; $script:iRecursos = @($nueva) }
        }
        if ($script:fiImg) {
            # el vídeo entero a lo alto (con bandas moradas a los lados); al final, zoom hacia la espiral
            $z = 1.0; if ($ms -gt $T.Niebla) { $z = 1.0 + [Math]::Pow(($ms - $T.Niebla) / ($T.Fin - $T.Niebla), 2) * 2.5 }
            $ih = $H * $z; $iw = $ih * $script:fiImg.Width / $script:fiImg.Height
            $g.DrawImage($script:fiImg, [float]($W / 2 - $iw / 2), [float]($H / 2 - $ih / 2), [float]$iw, [float]$ih)
        }
        if ($ms -gt $T.Niebla) {
            # la niebla rosa lo tapa todo
            $q = [Math]::Min(1.0, ($ms - $T.Niebla) / ($T.Fin - $T.Niebla - 200))
            Pintar-Niebla $g 0 $W $H (1.6 * $q)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * $q * $q), 255, 186, 244))), 0, 0, $W, $H)
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { $script:fiT0 = [Environment]::TickCount; Sonido 'intro' }
        $ms = [Environment]::TickCount - $script:fiT0
        if ($ms -gt $SfIntro.Fin -and $script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        # en el último paso (también si se salta) el panel queda tapado de niebla y se va despejando
        if ($script:iPaso -ge $script:iTotal - 1) { Sf-Niebla 1800 255 }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Roaring Knight: entrada de combate de Deltarune ("* The Roaring Knight appeared."), el Knight levanta la espada y ruge ---
# Va sincronizada con el reloj. Momentos (en milisegundos):
$KnIntro = @{ Texto = 500; Rugido = 3000; Fin = 4700 }
function Transicion-Knight($final) {
    $script:kiEnt = Cargar-Img 'skins\knight\entrada.gif'; $script:kiRoar = Cargar-Img 'skins\knight\roar.gif'
    $script:kiInfo = @{ e = (Gif-Info $script:kiEnt); r = (Gif-Info $script:kiRoar) }
    $script:iRecursos = @($script:kiEnt, $script:kiRoar); $script:kiT0 = 0; $script:kiHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $T = $KnIntro
        $ms = if ($script:kiT0 -gt 0) { [Environment]::TickCount - $script:kiT0 } else { 0 }
        $g.Clear([System.Drawing.Color]::Black)
        $pg = New-Object System.Drawing.Pen((C 52 18 82), 1); $desp = ($ms / 50) % 32
        for ($x = - 32 + $desp; $x -lt $W; $x += 32) { $g.DrawLine($pg, [float]$x, 0, [float]$x, $H) }
        for ($y = - 32 + $desp; $y -lt $H; $y += 32) { $g.DrawLine($pg, 0, [float]$y, $W, [float]$y) }
        $rug = $ms -ge $T.Rugido
        if ($rug) {
            # el rugido: rayos de luz roja
            $q = [Math]::Max(0.0, 1 - ($ms - $T.Rugido) / 1500.0)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](150 * $q), 200, 0, 20))), 0, 0, $W, $H)
            $pr = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int](230 * $q), 255, 70, 70), 5)
            for ($i = 0; $i -lt 14; $i++) { $a = $i * [Math]::PI / 7 + $ms / 600.0; $g.DrawLine($pr, [float]($W * 0.62), 120, [float]($W * 0.62 + [Math]::Cos($a) * 700), [float](120 + [Math]::Sin($a) * 700)) }
            $pr.Dispose()
        }
        $img = if ($rug) { $script:kiRoar } else { $script:kiEnt }; $inf = if ($rug) { $script:kiInfo.r } else { $script:kiInfo.e }
        if ($img) {
            # la entrada se ve una vez (no en bucle); el rugido sí se repite
            $mm = if ($rug) { $ms } else { $tot = 0; foreach ($d in $inf.Del) { $tot += $d }; [Math]::Min($ms, $tot - 1) }
            Gif-Frame $img $inf $mm
            $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
            $s = if ($rug) { 1.5 } else { 0.95 }; $iw = $img.Width * $s; $ih = $img.Height * $s
            $g.DrawImage($img, [float]($W * 0.62 - $iw / 2), [float](($H - 90) - $ih), [float]$iw, [float]$ih)
            $g.InterpolationMode = 'HighQualityBilinear'; $g.PixelOffsetMode = 'Default'
        }
        # cuadro de texto de abajo, letra a letra
        $txt = '* The Roaring Knight appeared.'
        $n = [Math]::Max(0, [Math]::Min($txt.Length, [int](($ms - $T.Texto) / 45)))
        $g.FillRectangle([System.Drawing.Brushes]::Black, 30, ($H - 82), ($W - 60), 66)
        $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)), 30, ($H - 82), ($W - 60), 66)
        $g.DrawString($txt.Substring(0, $n), (FntP('Consolas', 18, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 50, ($H - 66))
        if ($ms -gt $T.Fin - 500) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int][Math]::Min(255, ($ms - $T.Fin + 500) / 2), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { $script:kiT0 = [Environment]::TickCount; Sonido 'encuentro' }
        $ms = [Environment]::TickCount - $script:kiT0
        if ($ms -ge $KnIntro.Rugido -and -not $script:kiHechos.r) { $script:kiHechos.r = $true; Sonido 'rugido' }
        if ($ms -gt $KnIntro.Fin -and $script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Dybbuk: "Them Kitty Bones" (la canción del Boneyard). La cámara entra por la puerta del cementerio, Dybbuk se asoma
#     detrás de las lápidas, todo se queda a oscuras ("Ni la Muerte puede atraparme..."), sale su presentación de jefe
#     y un lametazo gigante limpia la pantalla ---
# Va sincronizada con el reloj (la música es un trozo de 18 s de la canción). Momentos (en milisegundos):
$DyIntro = @{ Titulo = 700; Asoma1 = 3200; Colina = 6300; Asoma2 = 7900; Asoma3 = 10000; Oscuro = 12700; Jefe = 14200; Lengua = 16900; Fin = 18100 }
# Dybbuk se asoma: sube desde abajo, mira y vuelve a esconderse (se dibuja antes del marco de lápidas, que lo tapa por abajo)
function Dy-Asoma($g, $cx, $base, $alto, $tt, $dur) {
    $img = $script:yiAsoma; if (-not $img -or $tt -lt 0 -or $tt -gt $dur) { return }
    Gif-Frame $img $script:yiAsomaInf $tt
    $sube = [Math]::Min(1.0, [Math]::Min($tt / 260.0, ($dur - $tt) / 260.0))
    $iw = $img.Width * $alto / $img.Height
    $g.DrawImage($img, [float]($cx - $iw / 2), [float]($base - $alto * $sube), [float]$iw, [float]$alto)
}
function Transicion-Dybbuk($final) {
    $k = $script:skin
    $script:yiPuerta = Cargar-Img $k.IntroPuerta; $script:yiColina = Cargar-Img $k.IntroColina; $script:yiJefe = Cargar-Img $k.IntroJefe
    $script:yiMarco = Cargar-Img $k.IntroMarco; $script:yiAsoma = Cargar-Img $k.IntroAsoma; $script:yiLapida = Cargar-Img $k.Lapida; $script:yiWisp = Cargar-Img $k.Wisp
    $script:yiAsomaInf = Gif-Info $script:yiAsoma
    $script:iRecursos = @($script:yiPuerta, $script:yiColina, $script:yiJefe, $script:yiMarco, $script:yiAsoma, $script:yiLapida, $script:yiWisp)
    $script:yiT0 = 0; $script:yiHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
        $YT = $DyIntro
        $ms = if ($script:yiT0 -gt 0) { [Environment]::TickCount - $script:yiT0 } else { 0 }
        $g.Clear([System.Drawing.Color]::Black)
        if ($ms -lt $YT.Oscuro) {
            if ($ms -lt $YT.Colina) {
                # 1) la puerta del cementerio: la cámara avanza despacio por el camino
                if ($script:yiPuerta) { [void](Dibujar-Cubriendo $g $script:yiPuerta $W $H (1.0 + ($ms / $YT.Colina) * 0.22) 0.5 0.6) }
                Dy-Asoma $g ($W * 0.78) ($H * 0.98) ($H * 0.42) ($ms - $YT.Asoma1) 1900
            } else {
                # 2) la colina del jefe bajo la luna, con fuegos fatuos flotando
                if ($script:yiColina) { [void](Dibujar-Cubriendo $g $script:yiColina $W $H (1.10 - (($ms - $YT.Colina) / ($YT.Oscuro - $YT.Colina)) * 0.08) 0.5 0.5) }
                if ($script:yiWisp) {
                    foreach ($q in @(@(0.18, 0.0), @(0.47, 2.1), @(0.83, 4.2))) {
                        $fx = $W * $q[0] + [Math]::Sin($ms / 900.0 + $q[1]) * 18; $fy = $H * 0.42 + [Math]::Sin($ms / 500.0 + $q[1]) * 12
                        Dy-Img $g $script:yiWisp $fx $fy 26 40 0.75
                    }
                }
                Dy-Asoma $g ($W * 0.17) ($H * 0.98) ($H * 0.54) ($ms - $YT.Asoma2) 1800
                Dy-Asoma $g ($W * 0.80) ($H * 0.98) ($H * 0.46) ($ms - $YT.Asoma3) 2300
            }
            # el marco de árboles y lápidas negras por delante de todo
            if ($script:yiMarco) { [void](Dibujar-Cubriendo $g $script:yiMarco $W $H 1.0 0.5 0.62) }
            # cartel del capítulo, como en el mapa del juego
            if ($ms -ge $YT.Titulo -and $ms -lt $YT.Titulo + 4600) {
                $tq = $ms - $YT.Titulo; $al = [Math]::Min(1.0, [Math]::Min($tq / 500.0, (4600 - $tq) / 600.0))
                if ($script:yiLapida) { Dy-Img $g $script:yiLapida 22 18 56 64 $al }
                Texto-Contorno $g 'CAPÍTULO 3' 'EdmundMcMillen_INTLv4' 14 88 24 (C 150 172 186) 3 ([int](255 * $al))
                Texto-Contorno $g 'THE BONEYARD' 'EdmundMcMillen_INTLv4' 30 86 42 (C 236 234 226) 5 ([int](255 * $al))
            }
            # "¡Cucú!" cuando se asoma por tercera vez
            if ($ms -ge $YT.Asoma3 + 300 -and $ms -lt $YT.Asoma3 + 2000) { Texto-Contorno $g '¡Cucú!' 'EdmundMcMillen_INTLv4' 26 ($W * 0.80 - 100) ($H * 0.40) (C 236 234 226) 5 }
            # se apaga la luz
            if ($ms -gt $YT.Oscuro - 700) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int][Math]::Min(255, ($ms - $YT.Oscuro + 700) * 255 / 700), 0, 0, 0))), 0, 0, $W, $H) }
        } elseif ($ms -lt $YT.Jefe) {
            # 3) a oscuras: la frase letra a letra y dos ojos que se abren
            $frase = 'Ni la Muerte puede atraparme...'
            $n = [Math]::Max(0, [Math]::Min($frase.Length, [int](($ms - $YT.Oscuro - 150) / 32)))
            $tw = Ancho-Texto $frase 'EdmundMcMillen_INTLv4' 22
            Texto-Contorno $g $frase.Substring(0, $n) 'EdmundMcMillen_INTLv4' 22 ($W / 2 - $tw / 2) ($H * 0.66) (C 236 234 226) 3
            $ab = [Math]::Max(0.0, [Math]::Min(1.0, ($ms - $YT.Oscuro - 500) / 400.0))
            foreach ($ox in @(-38, 38)) { $g.FillEllipse([System.Drawing.Brushes]::WhiteSmoke, [float]($W / 2 + $ox - 22), [float]($H * 0.40 - 10 * $ab), 44, [float](20 * $ab)); $g.FillRectangle([System.Drawing.Brushes]::Black, [float]($W / 2 + $ox - 2), [float]($H * 0.40 - 9 * $ab), 4, [float](18 * $ab)) }
        } else {
            # 4) la presentación del jefe, como en el juego: rayos, su arte de jefe y su nombre
            $tq = $ms - $YT.Jefe
            $sx = 0; $sy = 0; if ($tq -lt 450) { $sx = $Rnd.Next(-8, 9); $sy = $Rnd.Next(-6, 7) }
            $st = $g.Save(); $g.TranslateTransform([float]$sx, [float]$sy)
            $g.Clear((C 46 50 60))
            $rayo = New-Object System.Drawing.SolidBrush((C 60 66 80)); $cx = $W * 0.66; $cy = $H * 0.55
            for ($i = 0; $i -lt 12; $i++) {
                $a1 = $i * [Math]::PI / 6 + $tq / 2400.0; $a2 = $a1 + [Math]::PI / 12
                $g.FillPolygon($rayo, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$cx, [float]$cy)), (New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a1) * 1200), [float]($cy + [Math]::Sin($a1) * 1200))), (New-Object System.Drawing.PointF([float]($cx + [Math]::Cos($a2) * 1200), [float]($cy + [Math]::Sin($a2) * 1200)))))
            }
            $rayo.Dispose()
            # el arte entra desde la derecha con un pequeño rebote
            $q = [Math]::Min(1.0, $tq / 380.0); $ease = 1 + 2.2 * [Math]::Pow($q - 1, 3) + 1.2 * [Math]::Pow($q - 1, 2)
            if ($script:yiJefe) {
                $ih = $H * 0.96; $iw = $script:yiJefe.Width * $ih / $script:yiJefe.Height
                $bob = [Math]::Sin($tq / 380.0) * 4
                $g.DrawImage($script:yiJefe, [float]($W * 0.66 - $iw / 2 + (1 - $ease) * $W * 0.7), [float]($H - $ih + 6 + $bob), [float]$iw, [float]$ih)
            }
            # la franja de tinta con el nombre, desde la izquierda
            $q2 = [Math]::Min(1.0, [Math]::Max(0.0, ($tq - 150) / 320.0)); $ox = (1 - $q2) * -480
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 235 18 18 22))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$ox, [float]($H * 0.30))), (New-Object System.Drawing.PointF([float]($ox + 430), [float]($H * 0.26))), (New-Object System.Drawing.PointF([float]($ox + 400), [float]($H * 0.70))), (New-Object System.Drawing.PointF([float]$ox, [float]($H * 0.73)))))
            Texto-Contorno $g 'DYBBUK' 'EdmundMcMillen_INTLv4' 62 ($ox + 26) ($H * 0.30) (C 236 234 226) 8
            Texto-Contorno $g 'JEFE  ·  THE BONEYARD' 'EdmundMcMillen_INTLv4' 15 ($ox + 32) ($H * 0.53) (C 226 128 146) 4
            if ($tq -gt 900) { Texto-Contorno $g '"¡Pilla pilla! ¡Te toca!"' 'EdmundMcMillen_INTLv4' 13 ($ox + 32) ($H * 0.61) (C 150 172 186) 3 }
            $g.Restore($st)
            if ($tq -lt 140) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](200 * (1 - $tq / 140.0)), 255, 255, 255))), 0, 0, $W, $H) }
            # 5) el lametazo: una lengua gigante cruza la pantalla de derecha a izquierda
            if ($ms -ge $YT.Lengua) {
                $lq = [Math]::Min(1.0, ($ms - $YT.Lengua) / 750.0); $lq = 1 - (1 - $lq) * (1 - $lq)
                $alto = $H + 120; $punta = $W + 40 - $lq * ($W + $alto * 0.7)
                # la punta redonda con borde de tinta y, detrás, el resto de la lengua (tapa la otra mitad del borde)
                $rosa = New-Object System.Drawing.SolidBrush((C 222 120 138))
                $g.FillEllipse($rosa, [float]$punta, [float](-60), [float]($alto * 0.7), [float]$alto)
                $g.DrawEllipse((New-Object System.Drawing.Pen((C 22 22 26), 6)), [float]$punta, [float](-60), [float]($alto * 0.7), [float]$alto)
                $g.FillRectangle($rosa, [float]($punta + $alto * 0.35), [float](-70), [float]($W + 100), [float]($alto + 20)); $rosa.Dispose()
                $surco = New-Object System.Drawing.Pen((C 186 82 104), 7); $surco.StartCap = 'Round'
                $g.DrawLine($surco, [float]($punta + 90), [float]($H / 2), [float]($W + 60), [float]($H / 2)); $surco.Dispose()
                $brillo = New-Object System.Drawing.SolidBrush((ARGB 120 255 230 236))
                $g.FillEllipse($brillo, [float]($punta + 40), [float]($H * 0.22), 90, 40); $brillo.Dispose()
                $pap = New-Object System.Drawing.SolidBrush((C 204 100 120)); $rn = New-Object System.Random 7
                for ($i = 0; $i -lt 26; $i++) { $g.FillEllipse($pap, [float]($punta + 70 + $rn.Next(0, [int]($W + 60))), [float]($rn.Next(20, [int]($H - 20))), 7, 6) }
                $pap.Dispose()
            }
        }
    }
    $alTick = {
        param($ov, $p)
        $YT = $DyIntro
        if ($p -eq 1) { $script:yiT0 = [Environment]::TickCount; Sonido 'intro' }
        $ms = [Environment]::TickCount - $script:yiT0
        foreach ($ev in @(@($YT.Asoma1, 'a1', 'flip'), @($YT.Asoma2, 'a2', 'flip'), @($YT.Asoma3, 'a3', 'flip'), @($YT.Jefe, 'jefe', 'zombie'), @($YT.Lengua, 'lengua', 'lame'))) {
            if ($ms -ge $ev[0] -and -not $script:yiHechos.ContainsKey($ev[1])) { $script:yiHechos[$ev[1]] = $true; Sonido $ev[2] }
        }
        if ($ms -gt $YT.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        # al final la pantalla (llena de lengua) se va hacia arriba y aparece el panel
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 600 $pintar $alTick $final
}

# --- Ellie: vídeo cutre de "ALERTA". Sirena y luces rojas ("⚠ ALERTA ⚠ SELF INSERT DETECTADO"), ¡BUM!, sale el usuario de Ale
#     en grande con un círculo rojo pintado a mano y una flecha gigante señalándolo, otro ¡BUM! con zoom, glitch y aparece Ellie ---
# Va sincronizada con el reloj. Momentos (en milisegundos):
$ElIntro = @{ Boom1 = 3300; Circulo = 3800; Flecha = 4400; Boom2 = 5700; Glitch = 6900; Ellie = 7500; Fin = 9800 }
function Transicion-Ellie($final) {
    $k = $script:skin
    $script:liUser = Cargar-Img $k.Usuario; $script:liFondo = Cargar-Img $k.FondoImg; $script:liCuerpo = Cargar-Img $k.Gif
    $script:liRojo = if ($script:liCuerpo) { Imagen-Color $script:liCuerpo (C 255 30 90) 300 } else { $null }
    $script:liCian = if ($script:liCuerpo) { Imagen-Color $script:liCuerpo (C 60 230 255) 300 } else { $null }
    $script:iRecursos = @($script:liUser, $script:liFondo, $script:liCuerpo, $script:liRojo, $script:liCian)
    $script:liT0 = 0; $script:liHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAlias'
        $ET = $ElIntro
        $ms = if ($script:liT0 -gt 0) { [Environment]::TickCount - $script:liT0 } else { 0 }
        $fmc = New-Object System.Drawing.StringFormat; $fmc.Alignment = 'Center'
        if ($ms -lt $ET.Boom1) {
            # 1) la alarma: fondo rojo que late, dos focos de sirena girando y cinta de peligro arriba y abajo
            $lat = 0.5 + 0.5 * [Math]::Sin($ms / 140.0)
            $g.Clear([System.Drawing.Color]::FromArgb(255, [int](70 + 90 * $lat), 0, [int](8 + 10 * $lat)))
            $ang = $ms / 6.0
            foreach ($desf in @(0, 180)) { $g.FillPie((New-Object System.Drawing.SolidBrush((ARGB 70 255 220 200))), [float]($W / 2 - 700), [float]($H / 2 - 700), 1400, 1400, [float]($ang + $desf), 40) }
            $amar = New-Object System.Drawing.SolidBrush((C 255 210 0)); $neg = [System.Drawing.Brushes]::Black
            foreach ($cy in @(0, ($H - 30))) {
                $g.FillRectangle($amar, 0, $cy, $W, 30)
                $desp = ($ms / 12) % 40
                for ($x = -40 + $desp; $x -lt $W + 40; $x += 40) { $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, [float]$cy)), (New-Object System.Drawing.PointF([float]($x + 20), [float]$cy)), (New-Object System.Drawing.PointF([float]($x + 5), [float]($cy + 30))), (New-Object System.Drawing.PointF([float]($x - 15), [float]($cy + 30))))) }
            }
            $amar.Dispose()
            if (([int]($ms / 380)) % 2 -eq 0) {
                $tw = Ancho-Texto 'ALERTA' 'Impact' 64
                Texto-Contorno $g 'ALERTA' 'Impact' 64 ($W / 2 - $tw / 2) ($H * 0.22) (C 255 230 40) 9
                # dos señales de peligro (triángulo amarillo con "!") a los lados
                foreach ($tx0 in @(($W / 2 - $tw / 2 - 86), ($W / 2 + $tw / 2 + 18))) {
                    $tri = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($tx0 + 34), [float]($H * 0.24))), (New-Object System.Drawing.PointF([float]($tx0 + 68), [float]($H * 0.24 + 62))), (New-Object System.Drawing.PointF([float]$tx0, [float]($H * 0.24 + 62))))
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 255 230 40))), $tri)
                    $g.DrawPolygon((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 5)), $tri)
                    $g.FillRectangle([System.Drawing.Brushes]::Black, [float]($tx0 + 30), [float]($H * 0.24 + 20), 8, 24)
                    $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($tx0 + 29), [float]($H * 0.24 + 48), 10, 9)
                }
            }
            $tw = Ancho-Texto 'SELF INSERT DETECTADO' 'Impact' 30
            Texto-Contorno $g 'SELF INSERT DETECTADO' 'Impact' 30 ($W / 2 - $tw / 2) ($H * 0.58) (C 255 255 255) 6
        } elseif ($ms -lt $ET.Glitch) {
            # 2) el vídeo cutre: el usuario de Ale en grande, un círculo rojo a mano, una flecha gigante y zoom con ¡BUM!
            $g.Clear((C 14 10 18))
            $vig = New-Object System.Drawing.Drawing2D.GraphicsPath; $vig.AddEllipse([float](-$W * 0.2), [float](-$H * 0.4), [float]($W * 1.4), [float]($H * 1.8))
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($vig); $pg.CenterColor = (C 70 40 80); $pg.SurroundColors = @((C 14 10 18))
            $g.FillPath($pg, $vig); $pg.Dispose(); $vig.Dispose()
            $sx = 0; $sy = 0
            foreach ($bt in @($ET.Boom1, $ET.Boom2)) { if ($ms -ge $bt -and $ms -lt $bt + 350) { $sx = $Rnd.Next(-10, 11); $sy = $Rnd.Next(-8, 9) } }
            $st = $g.Save()
            if ($script:liUser) {
                $sc = ($W * 0.82) / $script:liUser.Width; $uw = $script:liUser.Width * $sc; $uh = $script:liUser.Height * $sc
                $ux = $W / 2 - $uw / 2; $uy = $H * 0.52 - $uh / 2
                $acx = $ux + 22 * $sc; $acy = $uy + 21.5 * $sc; $rad = 17 * $sc
                # zoom lento y, en el segundo ¡BUM!, zoom de golpe a la foto
                $z = 1.0 + ($ms - $ET.Boom1) / 30000.0
                if ($ms -ge $ET.Boom2) { $z = 1.0 + 1.1 * [Math]::Min(1.0, ($ms - $ET.Boom2) / 160.0) }
                $g.TranslateTransform([float]($acx + $sx), [float]($acy + $sy)); $g.ScaleTransform([float]$z, [float]$z); $g.TranslateTransform([float](-$acx), [float](-$acy))
                $g.InterpolationMode = 'NearestNeighbor'
                $g.DrawImage($script:liUser, [float]$ux, [float]$uy, [float]$uw, [float]$uh)
                $g.InterpolationMode = 'HighQualityBicubic'
                # el círculo rojo, dibujado a mano (dos vueltas un poco torcidas)
                if ($ms -ge $ET.Circulo) {
                    $q = [Math]::Min(1.0, ($ms - $ET.Circulo) / 450.0)
                    $pc = New-Object System.Drawing.Pen((C 235 20 20), 7); $pc.StartCap = 'Round'; $pc.EndCap = 'Round'
                    $g.DrawArc($pc, [float]($acx - $rad * 1.6), [float]($acy - $rad * 1.45), [float]($rad * 3.2), [float]($rad * 2.9), -100, [float](360 * $q))
                    if ($q -ge 1) { $g.DrawArc($pc, [float]($acx - $rad * 1.5), [float]($acy - $rad * 1.55), [float]($rad * 3.1), [float]($rad * 3.0), -80, 140) }
                    $pc.Dispose()
                }
                # la flecha gigante, entrando desde abajo a la derecha
                if ($ms -ge $ET.Flecha) {
                    $q = [Math]::Min(1.0, ($ms - $ET.Flecha) / 220.0)
                    $px = $acx + $rad * 1.5 + (1 - $q) * 300; $py = $acy + $rad * 1.2 + (1 - $q) * 200
                    $vx = 0.83; $vy = 0.56; $lar = 210; $anc = 22; $pun = 46
                    $nx = -$vy; $ny = $vx
                    $bx = $px + $vx * $pun; $by = $py + $vy * $pun; $ex = $px + $vx * $lar; $ey = $py + $vy * $lar
                    $fl = [System.Drawing.PointF[]]@(
                        (New-Object System.Drawing.PointF([float]$px, [float]$py)),
                        (New-Object System.Drawing.PointF([float]($bx + $nx * $anc * 2.2), [float]($by + $ny * $anc * 2.2))),
                        (New-Object System.Drawing.PointF([float]($bx + $nx * $anc), [float]($by + $ny * $anc))),
                        (New-Object System.Drawing.PointF([float]($ex + $nx * $anc), [float]($ey + $ny * $anc))),
                        (New-Object System.Drawing.PointF([float]($ex - $nx * $anc), [float]($ey - $ny * $anc))),
                        (New-Object System.Drawing.PointF([float]($bx - $nx * $anc), [float]($by - $ny * $anc))),
                        (New-Object System.Drawing.PointF([float]($bx - $nx * $anc * 2.2), [float]($by - $ny * $anc * 2.2))))
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 235 20 20))), $fl)
                    $g.DrawPolygon((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)), $fl)
                }
            }
            $g.Restore($st)
            # los textos del vídeo
            $tw = Ancho-Texto 'SELF INSERT DE ALE' 'Impact' 42
            Texto-Contorno $g 'SELF INSERT DE ALE' 'Impact' 42 ($W / 2 - $tw / 2 + $sx) 12 (C 255 230 40) 7
            $pie = if ($ms -ge $ET.Boom2) { 'ALE, ¿ERES TÚ?' } else { '(100% real, no fake)' }
            $tw = Ancho-Texto $pie 'Impact' 24
            Texto-Contorno $g $pie 'Impact' 24 ($W / 2 - $tw / 2) ($H - 46) (C 255 255 255) 5
            if ($ms -ge $ET.Boom2 -and $ms -lt $ET.Boom2 + 120) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), 0, 0, $W, $H) }
        } else {
            # 3) glitch y aparece Ellie, partida en rosa y cian, con su nombre corrompiéndose
            $g.Clear((C 16 6 16))
            if ($script:liFondo) { [void](Dibujar-Cubriendo $g $script:liFondo $W $H 1.0 0.85 0.5) }
            if ($ms -ge $ET.Ellie -and $script:liCuerpo) {
                $q = [Math]::Min(1.0, ($ms - $ET.Ellie) / 1800.0)
                $ih = $H * 0.96; $iw = $script:liCuerpo.Width * $ih / $script:liCuerpo.Height
                $ix = $W * 0.72 - $iw / 2; $iy = $H - $ih
                $sep = 14 * (1 - $q) + 2
                Dy-Img $g $script:liRojo ($ix - $sep) $iy $iw $ih 0.6
                Dy-Img $g $script:liCian ($ix + $sep) $iy $iw $ih 0.6
                $g.DrawImage($script:liCuerpo, [float]$ix, [float]$iy, [float]$iw, [float]$ih)
                $nom = if ($ms -lt $ET.Ellie + 900) { Revolver 'ELLIE VELÁZQUEZ' } else { 'ELLIE VELÁZQUEZ' }
                Texto-Contorno $g $nom 'Arial Black' 34 (30 - 3) ($H * 0.36) (C 90 230 255) 1 160
                Texto-Contorno $g $nom 'Arial Black' 34 (30 + 3) ($H * 0.36) (C 255 40 90) 1 160
                Texto-Contorno $g $nom 'Arial Black' 34 30 ($H * 0.36) (C 255 236 244) 6
                if ($ms -ge $ET.Ellie + 600) {
                    Texto-Contorno $g 'HUMANA CORRUPTA  ·  20 AÑOS' 'Arial Black' 14 34 ($H * 0.36 + 52) (C 255 92 170) 3
                    Texto-Contorno $g "SELF INSERT DE ALE  ·  ALE'S VERSION" 'Arial Black' 11 34 ($H * 0.36 + 76) (C 90 230 255) 3
                }
            }
            # bandas y bloques de glitch (más al principio)
            $fuerza = [Math]::Max(0.0, 1 - ($ms - $ET.Glitch) / 1300.0)
            $cols = @((C 255 40 80), (C 90 230 255), (C 255 230 60), (C 150 80 255), (C 255 255 255))
            for ($i = 0; $i -lt [int](4 + 40 * $fuerza); $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](120 + 120 * $fuerza), $cols[$Rnd.Next(5)].R, $cols[$Rnd.Next(5)].G, $cols[$Rnd.Next(5)].B))), [float]$Rnd.Next(-40, [int]$W), [float]$Rnd.Next(0, [int]$H), [float]$Rnd.Next(10, [int](40 + 300 * $fuerza)), [float]$Rnd.Next(3, 14)) }
            if ($ms -gt $ET.Fin - 500) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int][Math]::Min(255, ($ms - $ET.Fin + 500) / 2), 0, 0, 0))), 0, 0, $W, $H) }
        }
    }
    $alTick = {
        param($ov, $p)
        $ET = $ElIntro
        if ($p -eq 1) { $script:liT0 = [Environment]::TickCount; Sonido 'sirena' }
        $ms = [Environment]::TickCount - $script:liT0
        foreach ($ev in @(@($ET.Boom1, 'b1', 'boom'), @($ET.Flecha, 'f', 'tele'), @($ET.Boom2, 'b2', 'boom'), @($ET.Glitch, 'g', 'glitch'), @($ET.Ellie, 'e', 'tele'))) {
            if ($ms -ge $ev[0] -and -not $script:liHechos.ContainsKey($ev[1])) { $script:liHechos[$ev[1]] = $true; Sonido $ev[2] }
        }
        if ($ms -gt $ET.Fin -and $script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
    }
    Intro-Overlay 600 $pintar $alTick $final
}

# --- Nanachi: descenso al Abismo capa a capa, la entrada del escondite y Nanachi entre los hilos del campo de fuerza ---
# Va sincronizada con el reloj. Momentos (en milisegundos):
$NnIntro = @{ Caliz = 0; Capa4 = 2600; Entrada = 4700; Nanachi = 5600; Nombre = 6400; Fin = 8800 }
$NnCapas = @(@('1ª capa', 'Borde del Abismo', '0 – 1.350 m'), @('2ª capa', 'Bosque de la Tentación', '1.350 – 2.600 m'), @('3ª capa', 'Gran Falla', '2.600 – 7.000 m'), @('4ª capa', 'Cáliz de los Gigantes', '7.000 – 12.000 m'))
function Transicion-Nanachi($final) {
    $k = $script:skin
    $script:niCaliz = Cargar-Img 'skins\nanachi\intro_caliz.jpg'; $script:niCapa = Cargar-Img 'skins\nanachi\intro_capa4b.jpg'
    $script:niEntrada = Cargar-Img 'skins\nanachi\intro_entrada.jpg'; $script:niNana = Cargar-Img 'skins\nanachi\nanachi.png'
    $script:iRecursos = @($script:niCaliz, $script:niCapa, $script:niEntrada, $script:niNana)
    $script:niT0 = 0; $script:niHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $T = $NnIntro
        $ms = if ($script:niT0 -gt 0) { [Environment]::TickCount - $script:niT0 } else { 0 }
        $g.Clear((C 8 14 10))
        if ($ms -lt $T.Capa4 -and $script:niCaliz) {
            # 1) bajamos por el Abismo: la imagen alta se recorre de arriba abajo y van pasando las capas
            $q = $ms / [double]$T.Capa4
            [void](Dibujar-Cubriendo $g $script:niCaliz $W $H 1.0 0.5 $q)
            $i = [Math]::Min(3, [int]($q * 4))
            $c = $NnCapas[$i]; $al = [int](255 * [Math]::Min(1.0, (($q * 4) % 1.0) * 4))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($al * 0.55)) 0 0 0))), 0, ($H - 70), $W, 70)
            Texto-Color $g $c[0] 'Georgia' 22 30 ($H - 66) (ARGB $al 252 240 214) (ARGB $al 0 0 0) 4
            $g.DrawString("$($c[1])  ·  $($c[2])", (FntP('Georgia', 11, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((ARGB $al 236 170 190))), 32, [float]($H - 32))
            # profundidad que va bajando
            $m = [int]($q * 7100)
            Texto-Color $g ('{0:N0} m' -f $m) 'Consolas' 18 ($W - 150) 20 (C 252 240 214) (C 0 0 0) 4
        } elseif ($ms -lt $T.Entrada -and $script:niCapa) {
            # 2) la 4ª capa: cálices gigantes y cascadas, con zoom lento
            $z = 1.0 + ($ms - $T.Capa4) / 9000.0
            [void](Dibujar-Cubriendo $g $script:niCapa $W $H $z 0.5 0.5)
            Texto-Color $g '7.100 m' 'Consolas' 18 ($W - 150) 20 (C 252 240 214) (C 0 0 0) 4
            Texto-Color $g '4ª capa · Cáliz de los Gigantes' 'Georgia' 18 30 ($H - 50) (C 252 240 214) (C 0 0 0) 4
        } elseif ($script:niEntrada) {
            # 3) la entrada del escondite, con su luz verde; los hilos del campo de fuerza aparecen
            $z = 1.0 + ($ms - $T.Entrada) / 7000.0
            [void](Dibujar-Cubriendo $g $script:niEntrada $W $H $z 0.5 0.5)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 0 0 0))), 0, 0, $W, $H)
            Dibujar-Campo $g 0 0 $W $H ([int][Math]::Min(120.0, ($ms - $T.Entrada) / 8.0))
            if ($ms -ge $T.Nanachi -and $script:niNana) {
                # Nanachi sube desde abajo y se queda
                $q = [Math]::Min(1.0, ($ms - $T.Nanachi) / 500.0); $e = 1 - [Math]::Pow(1 - $q, 3)
                $nh = $H * 0.95; $nw = $script:niNana.Width * $nh / $script:niNana.Height
                $g.DrawImage($script:niNana, [float]($W * 0.74 - $nw / 2), [float]($H - $nh + (1 - $e) * $nh * 0.8 + [Math]::Sin($ms / 400.0) * 2), [float]$nw, [float]$nh)
            }
            if ($ms -ge $T.Nombre) {
                $q = [Math]::Min(1.0, ($ms - $T.Nombre) / 400.0); $e = 1 - [Math]::Pow(1 - $q, 3)
                Texto-Color $g 'NANACHI' 'Georgia' 60 (40 - (1 - $e) * 300) 70 (C 252 240 214) (C 60 40 30) 10
                if ($ms -ge $T.Nombre + 500) { Texto-Color $g 'Made in Abyss' 'Georgia' 18 46 150 (C 236 170 190) (C 30 20 14) 5 }
                if ($ms -ge $T.Nombre + 1000) {
                    $txt = 'Nnaa. ...¿qué?'; $n = [Math]::Min($txt.Length, [int](($ms - $T.Nombre - 1000) / 90))
                    Texto-Color $g $txt.Substring(0, $n) 'Segoe Print' 26 50 186 (C 255 255 255) (C 120 70 80) 6
                }
            }
        }
        # sale del negro al principio
        if ($ms -lt 600) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * (1 - $ms / 600.0)), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $T = $NnIntro
        if ($p -eq 1) { $script:niT0 = [Environment]::TickCount }
        $ms = [Environment]::TickCount - $script:niT0
        foreach ($ev in @(@(0, 'viento'), @(300, 'silbato'), @($T.Nanachi, 'brillo'))) {
            if ($ms -ge $ev[0] -and -not $script:niHechos.ContainsKey($ev[1])) { $script:niHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $T.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- intro de Malkuth: la sala de la Planta de Historia, Malkuth plantándole cara a Angela y ella con su libro ---
# La música es la suya (Malkuth Story): empieza con la intro y sigue sonando después sin cortarse.
$MkIntro = @{ Angela = 3200; Malkuth = 5800; Nombre = 6400; Fin = 9300 }
function Transicion-Malkuth($final) {
    $k = $script:skin
    $script:miPlanta = Cargar-Img $k.IntroPlanta; $script:miAngela = Cargar-Img $k.IntroAngela
    $script:miFondo = Cargar-Img $k.FondoImg; $script:miMalk = Cargar-Img 'skins\malkuth\malkuth.png'; $script:miEmb = Cargar-Img $k.Emblema
    $script:iRecursos = @($script:miPlanta, $script:miAngela, $script:miFondo, $script:miMalk, $script:miEmb)
    $script:miT0 = 0; $script:miHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $MT = $MkIntro
        $ms = if ($script:miT0 -gt 0) { [Environment]::TickCount - $script:miT0 } else { 0 }
        $g.Clear((C 24 16 8))
        if ($ms -lt $MT.Angela -and $script:miPlanta) {
            # 1) la sala de recepciones de la Planta de Historia, con zoom lento y el emblema de Malkuth
            [void](Dibujar-Cubriendo $g $script:miPlanta $W $H (1.0 + $ms / 12000.0) 0.5 0.45)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 20 12 4))), 0, 0, $W, $H)
            if ($script:miEmb) {
                $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float][Math]::Min(1.0, $ms / 900.0)
                $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm); $es = 110
                $g.DrawImage($script:miEmb, (New-Object System.Drawing.Rectangle([int]($W / 2 - $es / 2), [int]($H / 2 - $es / 2 - 30), $es, $es)), 0, 0, $script:miEmb.Width, $script:miEmb.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia); $ia.Dispose()
            }
            if ($ms -ge 700) {
                $al = [int](255 * [Math]::Min(1.0, ($ms - 700) / 500.0))
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($al * 0.55)) 0 0 0))), 0, ($H - 74), $W, 74)
                Texto-Color $g 'PLANTA DE HISTORIA' 'Palatino Linotype' 24 30 ($H - 70) (ARGB $al 250 232 180) (ARGB $al 40 24 8) 5
                $g.DrawString('1.ª planta de la Biblioteca  ·  Library of Ruina', (FntP('Palatino Linotype', 11, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((ARGB $al 236 196 106))), 32, [float]($H - 32))
            }
        } elseif ($ms -lt $MT.Malkuth -and $script:miAngela) {
            # 2) Malkuth le planta cara a Angela (escena del episodio 1) con el lema de L Corp
            [void](Dibujar-Cubriendo $g $script:miAngela $W $H (1.0 + ($ms - $MT.Angela) / 10000.0) 0.62 0.4)
            $txt = '«Enfrenta el pasado, construye el futuro.»'; $n = [Math]::Min($txt.Length, [int](($ms - $MT.Angela - 300) / 45))
            if ($n -gt 0) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 0 0 0))), 0, ($H - 56), $W, 56)
                Texto-Color $g $txt.Substring(0, $n) 'Palatino Linotype' 18 30 ($H - 46) (C 250 242 222) (C 30 20 10) 4
            }
        } elseif ($script:miFondo) {
            # 3) la planta de los diálogos: Malkuth sube desde abajo con su libro y sale su nombre
            [void](Dibujar-Cubriendo $g $script:miFondo $W $H (1.0 + ($ms - $MT.Malkuth) / 9000.0) 0.5 0.5)
            Degradado $g 0 0 ($W * 0.62) $H (ARGB 210 30 22 12) (ARGB 0 30 22 12) 0
            if ($script:miMalk) {
                $q = [Math]::Min(1.0, ($ms - $MT.Malkuth) / 550.0); $ee = 1 - [Math]::Pow(1 - $q, 3)
                $nh = $H * 0.98; $nw = $script:miMalk.Width * $nh / $script:miMalk.Height
                $g.DrawImage($script:miMalk, [float]($W * 0.78 - $nw / 2), [float]($H - $nh + (1 - $ee) * $nh * 0.8 + [Math]::Sin($ms / 450.0) * 2), [float]$nw, [float]$nh)
            }
            if ($ms -ge $MT.Nombre) {
                $q = [Math]::Min(1.0, ($ms - $MT.Nombre) / 400.0); $ee = 1 - [Math]::Pow(1 - $q, 3)
                Texto-Color $g 'MALKUTH' 'Palatino Linotype' 58 (40 - (1 - $ee) * 320) 60 (C 250 232 180) (C 60 36 12) 10
                if ($ms -ge $MT.Nombre + 450) { Texto-Color $g 'Bibliotecaria Patrona de la Planta de Historia' 'Palatino Linotype' 15 46 138 (C 236 196 106) (C 30 20 10) 5 }
                if ($ms -ge $MT.Nombre + 1000) {
                    $txt = '¡Encantada! ¡Que sea un combate justo!'; $n = [Math]::Min($txt.Length, [int](($ms - $MT.Nombre - 1000) / 55))
                    Texto-Color $g $txt.Substring(0, $n) 'Segoe UI' 20 48 176 (C 255 255 255) (C 120 70 20) 5
                }
            }
        }
        # motas doradas de polvo de biblioteca que suben despacio
        $tt = $ms / 1000.0
        for ($i = 0; $i -lt 26; $i++) {
            $px = ($i * 137 + 40) % $W + [Math]::Sin($tt + $i) * 8; $py = $H - (($tt * (18 + ($i % 7) * 4) + $i * 61) % ($H + 20))
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB (60 + ($i % 5) * 25) 255 220 140))), [float]$px, [float]$py, [float](2 + $i % 3), [float](2 + $i % 3))
        }
        # sale del negro al principio
        if ($ms -lt 600) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * (1 - $ms / 600.0)), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $MT = $MkIntro
        if ($p -eq 1) { $script:miT0 = [Environment]::TickCount; Mk-Reset; Mk-Musica-On }
        $ms = [Environment]::TickCount - $script:miT0
        foreach ($ev in @(@(250, 'pagina'), @($MT.Malkuth, 'libro'))) {
            if ($ms -ge $ev[0] -and -not $script:miHechos.ContainsKey($ev[1])) { $script:miHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $MT.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

[System.Windows.Forms.Application]::add_ThreadException({
    try {
        switch ($script:skin.Estilo) {
            'hacker' { Glitch 8 '> error interceptado. todo bajo control.' }
            'tele' { Corte-Senal 10; Decir '¡Bzzzt! Interferencias... ¡ya está!' }
            'mew' { Decir '*Guillotina se ha comido un error. Lo digiere.*' }
            'lobo' { Decir 'Incidente registrado y contenido, Manager.' 'serio' }
            'mlg' { Decir 'Lag. Ha sido lag. Yo no fallo.' }
            'oeste' { Decir '*Le dispara al error. Problema resuelto.*' }
            'culto' { Decir 'Cabra: Algo se ha roto. Ha sido el Cordero.' }
            'kaiju' { Decir 'WMEW 99.9: Una kaiju ha pisado un error. Ya no existe.' }
            'zorro' { Decir '¡Ups! Algo se ha roto... ¡No he sido yo! ...Bueno, quizá.' 'serio' }
            'pressure' { Decir 'Algo se ha roto. Lo pondré en oferta.' }
            'dod' { Decir '*Destroza el error de un zarpazo.*' }
            'pizza' { Decir '*Algo se ha roto. Kevin le da un mordisco al error.* Arreglado. Sabía a queso azul. PUAJ.' }
            'enfosi' { Decir 'Algo se ha roto. ¿Habrá sido un Enphosian? *Lo mira con desconfianza.*' }
            'punk' { Decir 'Algo se ha roto. No era la guitarra, por una vez. *Toca un acorde para arreglarlo.*' }
            'gran' { Decir 'Algo se ha roto. Un fallo del protocolo. Lo anoto y seguimos.' }
            'abismo' { Decir 'Algo se ha roto. Nnaa. Le pongo una venda y listo.' }
            'historia' { Decir 'Algo se ha roto. *Casi se tropieza con el error.* ¡Uoh! ...lo apunto en el registro de incidencias. Con un dibujito.' }
            'arana' { Decir 'Algo se ha roto, cielo. *Lo envuelve en seda.* Ya está. Lo que no se ve, no existe.' }
            'clima' { Decir 'Algo se ha roto... *Mira a cámara.* Tenemos problemas técnicos. No se vayan. Por favor, no se vayan.' }
            'pintor' { Decir 'Algo se ha roto. *(dibuja una carita asustada)* ¡Yo no he sido! ...bueno, a lo mejor el overclock. Un poco. Perdón.' }
            'evil' { Decir 'ALGO SE HA ROTO. *Evil Scary bota encima del error. El error desaparece. Tú casi también.*' }
            'niebla' { Decir 'Algo se ha roto. Yo no he sido: no puedo tocar nada. *Se pone transparente por si acaso.*' }
            'knight' { Decir '* Algo se ha roto. * El Knight lo ha cortado. * O igual ya venía roto.' }
            'corrupta' { Decir 'Algo se ha roto. ...vale, igual he sido yo. Un poquito. Es la corrupción, se me escapa.' }
            'boneyard' { Decir '*Algo se ha roto. Dybbuk le da un lametazo al error.* ¡Ya está! ...bueno, ahora está roto y pegajoso. Ñe-he-he.' }
            default { Decir 'Algo se ha roto. No he sido yo. Creo.' }
        }
    } catch {}
})

# ================= LÓGICA =================
function Nuevo-Boton($texto, $x, $y, $w, $h) {
    $k = $script:skin
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $k.BtnBorde
    $b.FlatAppearance.BorderSize = $k.BtnBordeAncho
    $b.FlatAppearance.MouseOverBackColor = $k.BtnHover
    $b.FlatAppearance.MouseDownBackColor = $k.BtnPress
    if ($k.Paleta) { $b.BackColor = $k.Paleta[$script:bi % $k.Paleta.Count]; $script:bi++ } else { $b.BackColor = $k.BtnFondo }
    $b.ForeColor = $k.BtnTexto
    $estilo = if ($k.Fuente -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $tam = if ($k.Fuente -in @('Impact', 'Bahnschrift', 'Georgia')) { 9.5 } elseif ($k.Fuente -eq 'Arial Black') { 8.5 } else { 10 }
    $b.Font = Fnt($k.Fuente, $tam, $estilo)
    $b.Cursor = 'Hand'
    $b.TabStop = $false
    # algunas skins dibujan sus propios botones (madera, papel, telarañas...)
    $b.Add_Paint({ Pintar-Boton $_.Graphics $this })
    $b.Add_MouseEnter({ $this.Invalidate() }); $b.Add_MouseLeave({ $this.Invalidate() })
    return $b
}

function Ruta-Redonda($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc([float]$x, [float]$y, [float]$r, [float]$r, 180, 90); $p.AddArc([float]($x + $w - $r), [float]$y, [float]$r, [float]$r, 270, 90)
    $p.AddArc([float]($x + $w - $r), [float]($y + $h - $r), [float]$r, [float]$r, 0, 90); $p.AddArc([float]$x, [float]($y + $h - $r), [float]$r, [float]$r, 90, 90)
    $p.CloseFigure(); return $p
}

function Dibujar-Telarana($g, $W, $H) {
    $g.SmoothingMode = 'AntiAlias'
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 255, 255, 255))), 0, 0, $W, $H)
    $seda = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, 245, 245, 250), [float](1.2 * $script:K))
    $cx = $W / 2; $cy = $H / 2; $n = 10
    $rad = @(); for ($i = 0; $i -lt $n; $i++) { $a = 2 * [Math]::PI * $i / $n; $rad += , @([Math]::Cos($a), [Math]::Sin($a)) }
    foreach ($d in $rad) { $g.DrawLine($seda, [float]$cx, [float]$cy, [float]($cx + $d[0] * $W * 0.62), [float]($cy + $d[1] * $H * 0.9)) }
    foreach ($f in @(0.25, 0.5, 0.78)) {
        $pts = New-Object 'System.Drawing.PointF[]' $n
        for ($i = 0; $i -lt $n; $i++) { $pts[$i] = New-Object System.Drawing.PointF([float]($cx + $rad[$i][0] * $W * 0.62 * $f), [float]($cy + $rad[$i][1] * $H * 0.9 * $f)) }
        $g.DrawPolygon($seda, $pts)
    }
    $seda.Dispose()
}

function Pintar-Boton($g, $b) {
    $k = $script:skin; $W = $b.Width; $H = $b.Height; $Z = $script:K
    $hover = $b.ClientRectangle.Contains($b.PointToClient([System.Windows.Forms.Cursor]::Position))
    $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF(0, 0, $W, $H)
    $enBarra = ($b.Parent -eq $form) -and ($b.Top -lt [int](52 * $Z))
    switch ($k.Estilo) {
        'oeste' {
            # cartel de madera con vetas y clavos
            $g.SmoothingMode = 'AntiAlias'
            $c1 = if ($hover) { (C 190 126 66) } else { (C 150 96 50) }; $c2 = if ($hover) { (C 150 96 48) } else { (C 110 66 32) }
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), $c1, $c2, 90)
            $g.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
            $veta = New-Object System.Drawing.Pen((C 92 56 28), [float](1 * $Z))
            foreach ($f in @(0.26, 0.5, 0.76)) { $y = [float]($H * $f); $g.DrawBezier($veta, [float](4 * $Z), $y, [float]($W * 0.3), [float]($y - 3 * $Z), [float]($W * 0.62), [float]($y + 3 * $Z), [float]($W - 4 * $Z), $y) }
            $veta.Dispose()
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 48 26 10), [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 2 * $Z), [float]($H - 2 * $Z))
            foreach ($nx in @((7 * $Z), ($W - 7 * $Z))) {
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 60 58 62))), [float]($nx - 2.5 * $Z), [float]($H / 2 - 2.5 * $Z), [float](5 * $Z), [float](5 * $Z))
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 170 170 175))), [float]($nx - 1.2 * $Z), [float]($H / 2 - 1.6 * $Z), [float](1.6 * $Z), [float](1.6 * $Z))
            }
            $sombra = New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1.5 * $Z), $W, $H)
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 50 28 12))), $sombra, $fmt)
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 252 238 205))), $rect, $fmt)
        }
        'mew' {
            # tarjeta de papel con borde de tinta irregular y sombra
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear((C 46 33 40))
            $r = New-Object System.Random([Math]::Abs($b.Text.GetHashCode()) % 9973)
            $j = { [float](($r.NextDouble() - 0.5) * 3 * $Z) }
            $x1 = 2 * $Z; $y1 = 2 * $Z; $x2 = $W - 5 * $Z; $y2 = $H - 5 * $Z
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x1 + (& $j)), [float]($y1 + (& $j)))), (New-Object System.Drawing.PointF([float]($x2 + (& $j)), [float]($y1 + (& $j)))), (New-Object System.Drawing.PointF([float]($x2 + (& $j)), [float]($y2 + (& $j)))), (New-Object System.Drawing.PointF([float]($x1 + (& $j)), [float]($y2 + (& $j)))))
            $somb = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 3 * $Z), ($_.Y + 3 * $Z)) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 18 10 12))), $somb)
            $papel = if ($hover) { (C 228 96 72) } else { (C 246 236 210) }
            $g.FillPolygon((New-Object System.Drawing.SolidBrush($papel)), $pts)
            $tinta = New-Object System.Drawing.Pen((C 20 14 16), [float](2.5 * $Z)); $tinta.LineJoin = 'Round'
            $g.DrawPolygon($tinta, $pts); $tinta.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 25 18 20))), (New-Object System.Drawing.RectangleF(0, 0, ($W - 3 * $Z), ($H - 3 * $Z))), $fmt)
        }
        'culto' {
            # losa del templo con borde rojo y rombos dorados en las esquinas
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 14 8 10) } else { (C 30 16 20) }))
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 3 * $Z) ($H - 3 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 120 20 30) } else { (C 40 26 30) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 150 24 36), [float](2 * $Z))), $r); $r.Dispose()
            $oro = New-Object System.Drawing.SolidBrush((C 214 170 60)); $d = 3 * $Z
            foreach ($q in @(@((5 * $Z), ($H / 2)), @(($W - 6 * $Z), ($H / 2)))) { $g.FillPolygon($oro, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$q[0], [float]($q[1] - $d))), (New-Object System.Drawing.PointF([float]($q[0] + $d), [float]$q[1])), (New-Object System.Drawing.PointF([float]$q[0], [float]($q[1] + $d))), (New-Object System.Drawing.PointF([float]($q[0] - $d), [float]$q[1])))) }
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 238 226 200))), $rect, $fmt)
        }
        'kaiju' {
            # cartel de película de monstruos: negro con borde naranja
            $g.Clear($(if ($enBarra) { (C 12 8 10) } else { (C 26 16 34) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 230 90 20) } else { (C 26 18 24) }))), 0, 0, $W, $H)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 200, 60))), [float](2 * $Z), [float](2 * $Z), [float]($W - 4 * $Z), [float](3 * $Z))
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 255 120 30), [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 2 * $Z), [float]($H - 2 * $Z))
            $sombra = New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1.5 * $Z), $W, $H)
            $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::Black, $sombra, $fmt)
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 250 230) } else { (C 255 236 200) }))), $rect, $fmt)
        }
        'femta' {
            # pegatina blanca con contorno negro y sombra roja; al pasar el ratón se pone roja
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 10 6 8) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float](3 * $Z), [float](3 * $Z), [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 230 20 40) } else { (C 255 255 255) }))), [float]$Z, [float]$Z, [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.DrawString($b.Text, $b.Font, $(if ($hover) { [System.Drawing.Brushes]::White } else { [System.Drawing.Brushes]::Black }), $rect, $fmt)
        }
        'punk' {
            # botón crema con borde marrón (como el bocadillo); al pasar el ratón, verde de pegatina
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 96 74 68) } else { (C 255 246 236) }))
            if ($script:bmpEscena) {
                # el trozo de fondo que queda detrás del botón (para que las esquinas redondas no se vean cuadradas)
                $pf = $form.PointToClient($b.PointToScreen([System.Drawing.Point]::Empty))
                $g.DrawImage($script:bmpEscena, (New-Object System.Drawing.Rectangle((-$pf.X), (-$pf.Y), $script:bmpEscena.Width, $script:bmpEscena.Height)))
            }
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 3 * $Z) ($H - 3 * $Z) ([Math]::Min(($H - 3 * $Z) / 2, 12 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 110 235 140) } else { (C 255 248 240) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 70 50 45))), $rect, $fmt)
        }
        'pizza' {
            # botón blanco dibujado con rotulador y sombra rosa; al pasar el ratón se pone verde Kevin
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 70 200 40) } else { (C 255 255 255) }))
            $sh = Ruta-Redonda (3 * $Z) (3 * $Z) ($W - 5 * $Z) ($H - 5 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($enBarra) { (C 30 100 240) } else { (C 255 110 200) }))), $sh); $sh.Dispose()
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 5 * $Z) ($H - 5 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 70 200 40) } else { (C 255 255 255) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 20 20 20), [float](2 * $Z))), $r); $r.Dispose()
            $rt = New-Object System.Drawing.RectangleF(0, 0, ($W - 3 * $Z), ($H - 3 * $Z))
            if ($hover) {
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 20 20 20))), (New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1.5 * $Z), ($W - 3 * $Z), ($H - 3 * $Z))), $fmt)
                $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::White, $rt, $fmt)
            } else { $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 20 20 20))), $rt, $fmt) }
        }
        'pop' {
            # pastilla morada con borde de neón cian; al pasar el ratón, rosa
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 70 20 90) } else { (C 26 12 48) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 12 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 92 190) } else { (C 44 20 78) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen($(if ($hover) { (C 255 255 255) } else { (C 90 230 250) }), [float](2 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((ARGB 120 255 92 190))), (New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1 * $Z), $W, $H)), $fmt)
            $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::White, $rect, $fmt)
        }
        'gran' {
            # botón de laboratorio: oscuro con borde verde; al pasar el ratón se llena de verde
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 9 12 10) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 5 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 32 208 44) } else { (C 14 22 16) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 32 208 44), [float](1.6 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 8 10 9) } else { (C 200 255 205) }))), $rect, $fmt)
        }
        'evil' {
            # botón oscuro con borde rojo; al pasar el ratón, rojo sangre
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 8 4 6) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 4 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 150 14 24) } else { (C 22 10 12) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 170 20 30), [float](1.6 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 236 220 220))), $rect, $fmt)
        }
        'boneyard' {
            # tarjeta de papel con borde de tinta irregular (como Mewgenics); al pasar el ratón, rosa lengua
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 22 23 28) } else { (C 34 36 42) }))
            $r = New-Object System.Random([Math]::Abs($b.Text.GetHashCode()) % 9973)
            $j = { [float](($r.NextDouble() - 0.5) * 3 * $Z) }
            $x1 = 2 * $Z; $y1 = 2 * $Z; $x2 = $W - 5 * $Z; $y2 = $H - 5 * $Z
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x1 + (& $j)), [float]($y1 + (& $j)))), (New-Object System.Drawing.PointF([float]($x2 + (& $j)), [float]($y1 + (& $j)))), (New-Object System.Drawing.PointF([float]($x2 + (& $j)), [float]($y2 + (& $j)))), (New-Object System.Drawing.PointF([float]($x1 + (& $j)), [float]($y2 + (& $j)))))
            $somb = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 3 * $Z), ($_.Y + 3 * $Z)) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 12 12 16))), $somb)
            $papel = if ($hover) { (C 226 128 146) } else { (C 238 236 226) }
            $g.FillPolygon((New-Object System.Drawing.SolidBrush($papel)), $pts)
            $tinta = New-Object System.Drawing.Pen((C 22 22 26), [float](2.5 * $Z)); $tinta.LineJoin = 'Round'
            $g.DrawPolygon($tinta, $pts); $tinta.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 22 22 26))), (New-Object System.Drawing.RectangleF(0, 0, ($W - 3 * $Z), ($H - 3 * $Z))), $fmt)
        }
        'corrupta' {
            # botón oscuro con borde rosa; al pasar el ratón, el texto se parte en rosa y cian
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 10 4 10) } else { (C 18 7 18) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 5 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 120 24 74) } else { (C 34 12 32) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 92 170), [float](1.6 * $Z))), $rr); $rr.Dispose()
            if ($hover) {
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 90 230 255))), (New-Object System.Drawing.RectangleF([float](-1.5 * $Z), 0, $W, $H)), $fmt)
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 255 40 90))), (New-Object System.Drawing.RectangleF([float](1.5 * $Z), 0, $W, $H)), $fmt)
            }
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 255 236 244))), $rect, $fmt)
        }
        'knight' {
            # botón negro con borde blanco; al pasar el ratón, amarillo (como una opción elegida en Deltarune)
            $g.SmoothingMode = 'None'
            $g.Clear([System.Drawing.Color]::Black)
            $col = if ($hover) { (C 255 255 0) } else { [System.Drawing.Color]::White }
            $g.DrawRectangle((New-Object System.Drawing.Pen($col, [float](2 * $Z))), [float](2 * $Z), [float](2 * $Z), [float]($W - 5 * $Z), [float]($H - 5 * $Z))
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($col)), $rect, $fmt)
        }
        'niebla' {
            # botón morado con borde rosa neón; al pasar el ratón, rosa como él
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 58 22 98) } else { (C 46 18 80) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 9 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 160 245) } else { (C 66 26 112) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 90 230), [float](1.6 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 40 10 60) } else { (C 255 225 250) }))), $rect, $fmt)
        }
        'abismo' {
            # botón de pergamino con borde de cuero; al pasar el ratón, rosa como su ropa
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 78 56 40) } else { (C 32 44 32) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 7 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 236 170 190) } elseif ($enBarra) { (C 64 46 32) } else { (C 246 236 212) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen($(if ($enBarra) { (C 236 170 190) } else { (C 92 70 52) }), [float](2 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($enBarra -and -not $hover) { (C 252 240 214) } else { (C 60 44 34) }))), $rect, $fmt)
        }
        'pintor' {
            # botón gris con relieve, como los de Windows de antes; al pasar el ratón, azul con letras blancas
            $g.SmoothingMode = 'None'
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 0 0 128) } else { (C 192 192 192) }))), 0, 0, $W, $H)
            $z1 = [float][Math]::Max(1.0, $Z)
            $pb = New-Object System.Drawing.Pen((C 255 255 255), $z1); $pg = New-Object System.Drawing.Pen((C 128 128 128), $z1); $pn = New-Object System.Drawing.Pen((C 0 0 0), $z1)
            $g.DrawLine($pb, 0, 0, ($W - 1), 0); $g.DrawLine($pb, 0, 0, 0, ($H - 1))
            $g.DrawLine($pn, 0, ($H - $z1 / 2), $W, ($H - $z1 / 2)); $g.DrawLine($pn, ($W - $z1 / 2), 0, ($W - $z1 / 2), $H)
            $g.DrawLine($pg, $z1, ($H - $z1 * 1.5), ($W - $z1), ($H - $z1 * 1.5)); $g.DrawLine($pg, ($W - $z1 * 1.5), $z1, ($W - $z1 * 1.5), ($H - $z1))
            $pb.Dispose(); $pg.Dispose(); $pn.Dispose()
            $g.TextRenderingHint = 'ClearTypeGridFit'
            $g.DrawString($b.Text, $b.Font, $(if ($hover) { [System.Drawing.Brushes]::White } else { [System.Drawing.Brushes]::Black }), $rect, $fmt)
        }
        'clima' {
            # papel de periódico con letra de imprenta (como las letras del vídeo); al pasar el ratón, azul eléctrico
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 100 116 162) } else { (C 136 148 182) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 80 10 14 40))), [float](3 * $Z), [float](3 * $Z), [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 63 91 217) } elseif ($enBarra) { (C 38 48 92) } else { (C 248 249 253) }))), [float]$Z, [float]$Z, [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 38 48 92), [float]$Z)), [float]$Z, [float]$Z, [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover -or $enBarra) { [System.Drawing.Color]::White } else { (C 30 38 74) }))), $rect, $fmt)
        }
        'arana' {
            # botón oscuro con borde rojo y una telarañita en la esquina; al pasar el ratón, rojo sangre
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 10 4 8) } else { (C 21 9 17) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 6 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 150 16 36) } else { (C 30 13 24) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 200 24 44), [float](1.6 * $Z))), $rr); $rr.Dispose()
            if (-not $enBarra) {
                $tp = New-Object System.Drawing.Pen((ARGB 90 230 225 235), [float](0.8 * $Z))
                foreach ($q in 1..3) { $g.DrawArc($tp, [float](-$q * 5 * $Z), [float](-$q * 5 * $Z), [float]($q * 10 * $Z), [float]($q * 10 * $Z), 0, 90) }
                $g.DrawLine($tp, 0, 0, [float](14 * $Z), [float](6 * $Z)); $g.DrawLine($tp, 0, 0, [float](6 * $Z), [float](14 * $Z)); $tp.Dispose()
            }
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 236 228 232))), $rect, $fmt)
        }
        'lobo' {
            # botón de la consola de L Corp: pizarra oscura, borde ámbar con esquinas marcadas; al pasar el ratón, ámbar
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 14 18 24) } else { (C 13 17 23) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 176 50) } else { (C 20 27 36) }))), [float](1.5 * $Z), [float](1.5 * $Z), [float]($W - 3 * $Z), [float]($H - 3 * $Z))
            $g.DrawRectangle((New-Object System.Drawing.Pen((ARGB 120 255 170 40), [float]$Z)), [float](1.5 * $Z), [float](1.5 * $Z), [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $esq = New-Object System.Drawing.Pen((C 255 170 40), [float](2 * $Z)); $L = 6 * $Z
            $g.DrawLines($esq, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$Z, [float]($Z + $L))), (New-Object System.Drawing.PointF([float]$Z, [float]$Z)), (New-Object System.Drawing.PointF([float]($Z + $L), [float]$Z))))
            $g.DrawLines($esq, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($W - 2 * $Z), [float]($H - 2 * $Z - $L))), (New-Object System.Drawing.PointF([float]($W - 2 * $Z), [float]($H - 2 * $Z))), (New-Object System.Drawing.PointF([float]($W - 2 * $Z - $L), [float]($H - 2 * $Z)))))
            $esq.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 12 14 18) } else { (C 220 232 240) }))), $rect, $fmt)
        }
        'historia' {
            # botón como el lomo de un libro: cuero marrón con filetes dorados; al pasar el ratón, dorado
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 96 68 32) } else { (C 38 28 18) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 4 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 236 196 106) } elseif ($enBarra) { (C 74 52 24) } else { (C 92 60 30) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 170 90), [float](1.6 * $Z))), $rr); $rr.Dispose()
            if (-not $enBarra) {
                $fil = New-Object System.Drawing.Pen((ARGB 140 236 196 106), [float]$Z)
                foreach ($fx2 in @((8 * $Z), ($W - 11 * $Z))) { $g.DrawLine($fil, [float]$fx2, [float](6 * $Z), [float]$fx2, [float]($H - 8 * $Z)) }
                $fil.Dispose()
            }
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 50 32 14) } else { (C 250 236 200) }))), $rect, $fmt)
        }
        'enfosi' {
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 252 200 55) } else { (C 34 38 54) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 9 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 214 60) } else { (C 255 255 255) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 25 25 25), [float](2 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 25 25 25))), $rect, $fmt)
        }
        'teto' {
            # botón blanco y rojo; al pasar el ratón se pone amarillo como sus medias
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 214 40 64) } else { (C 252 236 238) }))
            $r = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 14 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 232 140) } else { (C 255 250 248) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 40 64), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 176 24 48))), $rect, $fmt)
        }
        'zorro' {
            # pastilla crema con borde naranja
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 230 128 56) } else { (C 255 243 226) }))
            $r = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 22 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 214 170) } else { (C 255 250 240) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 230 128 56), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 110 60 30))), $rect, $fmt)
        }
        'pressure' {
            # placa metálica con esquinas ámbar; en la tienda muestra el objeto y su precio
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 8 10 14) } else { (C 12 16 20) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 36 96 104) } else { (C 20 26 32) }))), 0, 0, $W, $H)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 190 200), [float]$Z)), [float]($Z / 2), [float]($Z / 2), [float]($W - $Z), [float]($H - $Z))
            $esq = New-Object System.Drawing.Pen((C 255 190 70), [float](2 * $Z)); $L = 6 * $Z
            $g.DrawLines($esq, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$Z, [float]($Z + $L))), (New-Object System.Drawing.PointF([float]$Z, [float]$Z)), (New-Object System.Drawing.PointF([float]($Z + $L), [float]$Z))))
            $g.DrawLines($esq, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($W - $Z), [float]($H - $Z - $L))), (New-Object System.Drawing.PointF([float]($W - $Z), [float]($H - $Z))), (New-Object System.Drawing.PointF([float]($W - $Z - $L), [float]($H - $Z)))))
            $esq.Dispose()
            if ($b.Tag -is [hashtable] -and $b.Tag.Tienda) {
                $it = $b.Tag.Tienda; $s = $H - 8 * $Z
                Dibujar-Objeto $g $it.Id (4 * $Z) (4 * $Z) $s
                $fi = New-Object System.Drawing.StringFormat; $fi.LineAlignment = 'Center'
                $g.DrawString($it.Nombre, $b.Font, (New-Object System.Drawing.SolidBrush((C 220 240 245))), (New-Object System.Drawing.RectangleF([float]($s + 7 * $Z), 0, [float]($W - $s - 34 * $Z), [float]$H)), $fi)
                $fd = New-Object System.Drawing.StringFormat; $fd.Alignment = 'Far'; $fd.LineAlignment = 'Center'
                $g.DrawString("$($it.Precio)", $b.Font, (New-Object System.Drawing.SolidBrush((C 255 190 70))), (New-Object System.Drawing.RectangleF(0, 0, [float]($W - 6 * $Z), [float]$H)), $fd)
            } else {
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 255 255) } else { (C 220 240 245) }))), $rect, $fmt)
            }
        }
        'dod' {
            # botón negro con borde verde, como la interfaz de Die of Death
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 4 8 6) } else { (C 6 12 8) }))
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 3 * $Z) ($H - 3 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 0 110 78) } else { (C 8 14 10) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 0 160 110), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 255 255) } else { (C 200 255 230) }))), $rect, $fmt)
        }
    }
    if ($script:telarana -and $b.Tag -is [hashtable] -and [object]::ReferenceEquals($b.Tag, $script:telarana)) { Dibujar-Telarana $g $W $H }
    # Velvet: en la trampa del abracito, todos los botones quedan cubiertos de telaraña un momento
    elseif ($k.Estilo -eq 'arana' -and $script:vv -and $script:vv.TrampaT -gt $VvTiempos.TrampaFin -and $b.Parent -eq $script:grid) { Dibujar-Telarana $g $W $H }
}

function Hover-Color($b) {
    $col = $b.ForeColor; $hov = $script:skin.BtnTextoHover
    $b.Add_MouseEnter({ $this.ForeColor = $hov }.GetNewClosure())
    $b.Add_MouseLeave({ $this.ForeColor = $col }.GetNewClosure())
}

function Lanzar($item) {
    $k = $script:skin
    # Velvet: si el botón está atrapado en una telaraña, el primer clic la rompe
    if ($script:telarana -and [object]::ReferenceEquals($script:telarana, $item)) {
        $script:telarana = $null; $telTimer.Stop()
        foreach ($c in $script:grid.Controls) { $c.Invalidate() }
        Decir '*Rompes la telaraña.* Qué fuerte eres, cielo... vuelve a pulsar para abrirlo.'
        return
    }
    $linea = Azar $k.PorApp[$item.Nombre]
    if (-not $linea) { $linea = Azar $k.Frases }
    try {
        # %USERPROFILE% y parecidos se cambian por la carpeta de verdad (para botones de carpetas)
        Start-Process ([Environment]::ExpandEnvironmentVariables($item.Abrir)) -ErrorAction Stop
        switch ($k.Estilo) {
            'hacker' { Glitch 3 $linea }
            'tele' { Corte-Senal 4; Decir $linea }
            'mew' { Guillotina-Ataque 'come' $linea }
            'lobo' { Ag-App $linea }
            'arana' { Vv-App $linea }
            'clima' { Wg-App $linea $item.Nombre }
            'pintor' { Pr-App $linea $item.Nombre }
            'mlg' {
                $script:lanzadas++; $script:hitsTotal++
                Nuevo-Hit ([int]($Rnd.Next(30, 160) * $script:K)) ([int]($Rnd.Next(25, 125) * $script:K))
                if ($script:lanzadas % 4 -eq 0) { $script:dew++; Sonido 'dew'; Decir '¡DO THE DEW! *Velocidad aumentada.*' }
                else { Sonido 'disparo'; Decir $linea }
                $form.Invalidate()
            }
            'oeste' {
                if (Zodiac-Disparo) { Decir $linea } else { Decir '*click* ...*click* ¡Sin balas! Haz clic en Zodiac para recargar.' }
            }
            'culto' {
                # cada app es un seguidor nuevo; cada 5, un ritual
                $script:seguidores++; $script:fe = [Math]::Min(100, $script:fe + 6)
                if ($script:seguidores % 5 -eq 0) { Culto-Ritual } else { if ($Rnd.Next(2) -eq 0) { Sonido 'balido' }; Decir $linea; $form.Invalidate() }
            }
            'kaiju' { Kaiju-Ataque (@('P', 'Z')[$Rnd.Next(2)]) $linea }
            'pressure' { $script:investigacion += 2; Flotante '+2' 150 262 (C 120 230 240) 22 'Bahnschrift'; Decir $linea; $form.Invalidate() }
            'dod' { Pursuer-Ataque 'presa' $linea }
            'femta' {
                $script:tkFichas++; Sonido 'moneda'
                Flotante '+1 TOKEN' 180 262 (C 255 60 70) 20 'Consolas'
                if ($script:tkFichas % 10 -eq 0) { Token-Breakcore } else { Decir $linea }
                $form.Invalidate()
            }
            'pop' {
                if (Tetra-Mensaje) { Decir $linea } else { Decir "$linea (Te ha llegado un mensaje, pero estás en No molestar.)" }
                $form.Invalidate()
            }
            'enfosi' {
                # cada app trae un Glaggle a la estatua
                if ($script:ef -and -not $script:ef.W -and -not $script:ef.Banner -and -not $script:ef.Cartel) { Enfosi-Llega }
                else { if ($script:ef) { $script:ef.Cola++ }; Decir $linea }
            }
            'teto' {
                Teto-Pajaro
                $nv = @{ 'YouTube' = 'youtube'; 'Word' = 'word'; 'Excel' = 'excel'; 'Teams' = 'teams' }[$item.Nombre]
                if ($nv) { Sonido $nv } else { Sonido (Azar @('okay', 'letsgo', 'yay')) }
                $script:tetoVozT = [Environment]::TickCount
                Decir $linea
            }
            'pizza' {
                # con las apps de oficina, a veces se sienta a trabajar... y se cae de la silla
                if ($item.Nombre -in @('Word', 'Excel', 'PowerPoint', 'Access', 'Outlook', 'OneNote', 'Publisher', 'Teams') -and $Rnd.Next(3) -eq 0) {
                    Actor-Pose 'V' 'trabajo' 3100; Decir (Azar $k.Trabajo)
                } else { Kevin-Comer $linea }
            }
            'punk' { Ky-App $linea }
            'gran' { Gran-Dosis $linea }
            'abismo' { Nn-App $linea }
            'historia' { Mk-App $linea }
            'evil' { Es-App $linea }
            'niebla' { Sf-App $linea }
            'knight' { Kn-App $linea }
            'corrupta' { El-App $linea }
            'boneyard' { Dy-App $linea }
            'zorro' {
                $script:antojo = [Math]::Min(100, $script:antojo + 5); $form.Invalidate()
                if ($Rnd.Next(4) -eq 0) { Sonido 'ups'; Decir (Azar $k.Torpe) 'serio' } else { Decir $linea 'abiertos' }
            }
            'gunsaw' {
                if ($k.Hambre) {
                    $script:hambre = [Math]::Min(100, $script:hambre + 6); $form.Invalidate()
                    if ($script:hambre -ge 100) { Decir "DUNE COMER $($item.Nombre.ToUpper()). ÑAM. (tranquilo, se ha abierto igual)" } else { Decir $linea }
                } else { Decir $linea }
            }
            default { Decir $linea }
        }
    } catch {
        if ($item.Web) {
            Start-Process ([Environment]::ExpandEnvironmentVariables($item.Web))
            switch ($k.Estilo) {
                'hacker' { Decir "> $($item.Nombre) not found. redirecting to web..." }
                'tele' { Decir "¡No tengo $($item.Nombre) en la tele! ¡Te pongo la versión web!" }
                'mew' { Decir "*No encuentra $($item.Nombre). Se come la versión web.*" }
                'lobo' { Decir "$($item.Nombre) no está instalado. Redirigiendo a la versión web, Manager." 'serio' }
                'mlg' { Decir "No tienes $($item.Nombre). Te abro la web. Rápido como un hitscan." }
                'oeste' { Decir "*No encuentra $($item.Nombre) en el saloon. Abre la versión web.*" }
                'culto' { Decir "Cabra: No tienes $($item.Nombre). Te abro la web. El culto proveerá." }
                'kaiju' { Decir "WMEW 99.9: $($item.Nombre) ha sido aplastado. Abriendo la versión web entre los escombros." }
                'zorro' { Decir "¡No encuentro $($item.Nombre)! ...¡Te abro la web! ¿Vale? Vale." 'serio' }
                'femta' { Sonido 'glitch'; Decir "$($item.Nombre) N0T F0UND. Te abro la web. A todo volumen." }
                'pop' { Decir "No tienes $($item.Nombre). Te abro la web. Tranqui." }
                'enfosi' { Decir "No tienes $($item.Nombre). Te abro la web. Mientras, vigila la estatua." }
                'teto' { Sonido 'oops'; Decir "¡No encuentro $($item.Nombre)! Te abro la web. ...¿qué estábamos buscando?" }
                'pizza' { Decir "¡No tienes $($item.Nombre)! Te abro la web. Mientras carga, me como un trozo. *ÑAM.*" }
                'punk' { Decir "No tienes $($item.Nombre). Te abro la web. Como cuando no tienes la guitarra y tocas con la de un amigo." }
                'gran' { Decir "No tiene $($item.Nombre). Le abro la web. Anote el fallo en su expediente." }
                'abismo' { Decir "No tienes $($item.Nombre). Te abro la web. Es como mandar un globo de correo: llega igual, pero más tarde." }
                'historia' { Decir "No tienes $($item.Nombre). ¡Te abro la web! Un libro prestado de otra biblioteca también cuenta, ¿eh?" }
                'pintor' { Sonido 'error'; Decir "No tienes $($item.Nombre). Te abro la web. *(dibuja un enlace roto)* Ahí dentro hay de todo. Menos paisajes bonitos." }
                'clima' { Sonido 'tele'; Decir "No tienes $($item.Nombre). Te abro la web... *Mira a cámara.* Conectamos en directo con internet." }
                'arana' { Decir "No tienes $($item.Nombre), cielo. Te abro la web. La web... qué palabra tan bonita. Es mi especialidad." }
                'evil' { Decir "$($item.Nombre.ToUpper()) NO ESTÁ INSTALADO. ABRIENDO LA WEB. *Evil Scary te mira cargarla. No parpadea. No tiene ojos.*" }
                'niebla' { Decir "No tienes $($item.Nombre). Te abro la web. Internet es como yo: está en todas partes y no se puede tocar." }
                'knight' { Decir "* No tienes $($item.Nombre). * Te abro la web. * La sombra de la Fuente llega igual." }
                'corrupta' { Decir "No tienes $($item.Nombre). Te abro la web. Saltar entre dimensiones es lo mío." }
                'boneyard' { Decir "No tienes $($item.Nombre). Te abro la web. *Le da un lametazo mientras carga.* Así carga más rápido. Creo." }
                default { Decir "$($item.Nombre) no está instalado. Te abro la web. De nada." }
            }
        } else {
            switch ($k.Estilo) {
                'hacker' { Glitch 6 "> ERROR: $($item.Nombre) resisted the hack" }
                'tele' { Corte-Senal 10; Decir "¡Bzzzt! No encuentro el canal $($item.Nombre)..." }
                'mew' { Decir "*Busca $($item.Nombre) por todas partes. No está. Se enfada.*" }
                'lobo' { Decir "Error: $($item.Nombre) no localizado. Revise la instalación, Manager." 'serio' }
                'mlg' { Cara 'clic' 2500; Decir "Fallé el tiro: $($item.Nombre) no existe. Eso nunca pasa. Nunca." }
                'oeste' { Cara 'vacio' 1800; Decir "¡$($item.Nombre) ha huido del pueblo! Cobarde." }
                'culto' { Decir "Cordero: *Busca $($item.Nombre) por todo el templo. No está.* · Cabra: Hereje." }
                'kaiju' { Decir "WMEW 99.9: No hay rastro de $($item.Nombre). Probablemente aplastado." }
                'zorro' { Sonido 'ups'; Decir "¡No encuentro $($item.Nombre) por ningún lado! ¡Lo siento muchísimo!" 'serio' }
                'femta' { Sonido 'glitch'; $a = $script:actores['K']; if ($a) { $a.Temblor = 10 }; Decir "ERR0R: $($item.Nombre) no existe. *Token le pega un cabezazo a la pantalla. Sigue sin existir.*" }
                'pop' { Decir "No encuentro $($item.Nombre). Como esos amigos de 2020. Se fue y ya." }
                'enfosi' { Sonido 'buzzer'; Decir "¡$($item.Nombre) no aparece! Como la cara de un Enphosian disfrazado." }
                'teto' { Sonido 'uhoh'; Decir "¡$($item.Nombre) se ha ido volando! Como un pájaro. Igual vuelve." }
                'pizza' { Actor-Pose 'V' 'sudor' 2000; Decir "¡No encuentro $($item.Nombre)! ...¿Alguien lo ha tocado? ¿Como a mi pizza? *Suda.*" }
                'punk' { Decir "No encuentro $($item.Nombre). Como mis canciones sin terminar: igual algún día aparece." }
                'gran' { Gran-Tapar 3000; Decir "$($item.Nombre) no está. Un sujeto que se escapa del estudio. No pasará dos veces." }
                'abismo' { Nn-Cara 'nnaa' 2000; Decir "No encuentro $($item.Nombre). Se habrá caído al Abismo. Lo que cae ahí no vuelve." }
                'historia' { Mk-Fallo "No encuentro $($item.Nombre)... *Busca en todas las estanterías.* Lo siento. Debería haberlo tenido preparado." }
                'pintor' { Sonido 'error'; Pr-Cara 'mareo' 3500; Decir "$($item.Nombre) no está. *(se le cruzan los ojos)* Lo he buscado en toda la red del Blacksite. Hasta en las torretas. Nada." }
                'clima' { Sonido 'trueno'; Decir "No encuentro $($item.Nombre)... *Revisa el guion.* Aquí pone que hoy habría claros. Se ve que no." }
                'arana' { Sonido 'siseo'; Decir "$($item.Nombre) no está, cariño. Se habrá escapado de la telaraña. *Se relame.* Ya volverá. Siempre vuelven." }
                'evil' { Es-Reset; Es-Rebote 3.0; Decir "NO SE ENCUENTRA $($item.Nombre.ToUpper()). *Se lo ha comido. O lo ha atravesado. Da igual.*" }
                'niebla' { Actor-Pose 'F' 'cara' 1500; Decir "No encuentro $($item.Nombre). Se habrá vuelto niebla. Me pasa a mí también." }
                'knight' { Actor-Pose 'K' 'risa' 1500; Decir "* $($item.Nombre) no está. * El Knight se lo ha llevado por la Gran Puerta. * Como a Undyne." }
                'corrupta' { El-Rabia 8; Decir "¿$($item.Nombre)? No existe en este universo. Y eso me pone de MUY mal humor." }
                'boneyard' { Actor-Pose 'D' 'flip' 800; Decir "No encuentro $($item.Nombre). ¡Se ha escondido! ¡Como yo detrás de una lápida! Ñe-he-he." }
                default { Decir "No encuentro $($item.Nombre). Igual nunca existió." }
            }
        }
    }
}

function Mostrar-Pagina {
    $grid.Controls.Clear()
    $script:bi = 0
    $hacker = $script:skin.Estilo -in @('hacker', 'mlg', 'gunsaw')
    # el texto de la página vuelve a su tamaño normal (el menú Skins lo hace más pequeño)
    $script:lblPag.Font = Fnt($script:lblPag.Font.FontFamily.Name, 10, $script:lblPag.Font.Style)
    if ($script:modoSkins) {
        # una página por grupo (ver $GruposSkins): nombre de la skin y, debajo, de dónde viene
        $ps = Paginas-Skins
        if ($script:pagSkins -lt 0 -or $script:pagSkins -ge $ps.Count) { $script:pagSkins = 0 }
        $pg = $ps[$script:pagSkins]; $i = 0
        foreach ($it in $pg.Items) {
            $n = $it.Nombre
            $txt = if ($n -eq $script:skinNombre) { "[ $n ]" } else { $n }
            if ($it.Origen) { $txt = "$txt`n$($it.Origen)" }
            $b = Nuevo-Boton $txt (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
            $b.Font = Fnt($b.Font.FontFamily.Name, $(if ($n.Length -gt 12) { 7 } else { 7.5 }), $b.Font.Style)
            $b.Tag = $n
            $b.Add_Click({ Aplicar-Skin $this.Tag })
            # al pasar el ratón, el asistente opina de esa skin
            $b.Add_MouseEnter({ if (-not (Ocupado)) { Decir (Opinion $this.Tag) 'abiertos' } })
            if ($hacker) { Hover-Color $b }
            Escalar $b; $grid.Controls.Add($b); $i++
        }
        $parte = if ($pg.Partes -gt 1) { " $($pg.Parte)" } else { '' }
        $script:lblPag.Font = Fnt($script:lblPag.Font.FontFamily.Name, 8.5, $script:lblPag.Font.Style)
        $script:lblPag.Text = "$($pg.Grupo)$parte ($($script:pagSkins + 1)/$($ps.Count))"
        return
    }
    if ($script:modoTienda -and $script:skin.Tienda) {
        # tienda de Sebastian: los objetos ocupan la cuadrícula de botones
        $i = 0
        foreach ($it in $script:skin.Tienda) {
            $b = Nuevo-Boton $it.Nombre (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
            $b.Font = Fnt($b.Font.FontFamily.Name, 7.5, [System.Drawing.FontStyle]::Bold)
            $b.Tag = @{ Tienda = $it }
            $b.Add_Click({ Tienda-Comprar $this.Tag.Tienda })
            Escalar $b; $grid.Controls.Add($b); $i++
        }
        $b = Nuevo-Boton 'Salir' (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
        $b.Add_Click({ Tienda-Salir }); Escalar $b; $grid.Controls.Add($b)
        $script:lblPag.Text = 'Tienda'
        return
    }
    if ($script:pagina -ge $script:totalPaginas) { $script:pagina = $script:totalPaginas - 1 }
    $inicio = $script:pagina * $PorPagina
    $fin = [Math]::Min($inicio + $PorPagina, @($script:Botones).Count) - 1
    $i = 0
    $deEstaPagina = if ($fin -ge $inicio) { @($script:Botones)[$inicio..$fin] } else { @() }
    foreach ($item in $deEstaPagina) {
        $b = Nuevo-Boton $item.Nombre (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
        $b.Tag = $item
        $b.Add_Click({ Lanzar $this.Tag })
        if ($hacker) { Hover-Color $b }
        Escalar $b; $grid.Controls.Add($b); $i++
    }
    $script:lblPag.Text = "Page $($script:pagina + 1)/$totalPaginas"
}

function Efecto-Entrada($prev) {
    $msg = Mensaje-Entrada $prev
    # sin intros: solo saluda
    if (-not $script:aj.Intros -or $script:aj.Epilepsia) { Decir $msg 'abiertos'; return }   # el modo seguro también quita las intros
    switch ($script:skin.Estilo) {
        'hacker' { Glitch 10 $msg }
        'web' { Transicion-Web $msg }
        'tele' { Transicion-Estatica $msg }
        'mew' { Transicion-Boss $msg }
        'lobo' { Transicion-Lobo $msg }
        'mlg' { Transicion-Scope $msg }
        'oeste' { Transicion-Wanted $msg }
        'gunsaw' { Transicion-Gunsaw $msg }
        'culto' { Transicion-Culto $msg }
        'kaiju' { Transicion-Kaiju $msg }
        'zorro' { Transicion-Zorro $msg }
        'pressure' { Transicion-Vent $msg }
        'dod' { Transicion-DoD $msg }
        'teto' { Transicion-Teto $msg }
        'enfosi' { Transicion-Enfosi $msg }
        'femta' { Transicion-Token $msg }
        'pop' { Transicion-Pop $msg }
        'pizza' { Transicion-Pizza $msg }
        'punk' { Transicion-Punk $msg }
        'gran' { Transicion-Gran $msg }
        'abismo' { Transicion-Nanachi $msg }
        'historia' { Transicion-Malkuth $msg }
        'arana' { Transicion-Velvet $msg }
        'clima' { Transicion-Clima $msg }
        'pintor' { Transicion-Pintor $msg }
        'evil' { Transicion-Evil $msg }
        'niebla' { Transicion-Fuzzy $msg }
        'knight' { Transicion-Knight $msg }
        'corrupta' { Transicion-Ellie $msg }
        'boneyard' { Transicion-Dybbuk $msg }
    }
}

# ================= GUÍA DEL PANDA =================
# La primera vez que abres el panel, el panda rojo de JOSEPABLINI CORPORATION te da la bienvenida y te enseña lo básico.
# Se vuelve a ver desde Ajustes → Guía del panda. Al terminarla (o saltarla) se apunta en ajustes.txt (Guia = si).
# Cada paso es @('qué se ilumina', 'texto'). Lo que se puede iluminar: nada, botones, paginas, skins, personaje, ajustes, barra
$PasosGuia = @(
    , @('nada', '¡Hola! Bienvenido a c00lgui. Soy el panda rojo de JOSEPABLINI CORPORATION y te voy a enseñar lo básico del panel. Es muy rápido, ¡prometido!')
    , @('botones', 'Estos botones abren tus cosas con un clic: YouTube, Word, Excel, el Bloc de notas... Si no tienes una app de Office instalada, te abro su versión web.')
    , @('paginas', 'Con < y > cambias de página. En la página 2 están los enlaces a GitHub y a Wikipedia, y algunas cosas más.')
    , @('skins', 'En Skins cambias de personaje. Cada uno tiene su estilo, sus frases, su intro y su minijuego. Van por grupos (YouTube, Roblox...) y el panel recuerda el último que elegiste.')
    , @('personaje', 'Este es tu asistente. Hazle clic y te contesta (o pasa algo, según la skin). Con clic derecho llama a otro personaje y se ponen a discutir.')
    , @('ajustes', 'En Ajustes quitas el sonido o las intros, cambias el tamaño y la opacidad... y con "Editar botones" pones tus propios botones en el orden que quieras.')
    , @('barra', 'Para mover el panel, arrástralo desde el título de arriba. Con _ lo minimizas y con X lo cierras.')
    , @('nada', 'Las intros tienen un botón SALTAR abajo a la derecha. Si quieres volver a verme, estoy en Ajustes → Guía del panda. ¡Eso es todo! Fear the Spaggety Code, Build the Larp.')
)
$script:guia = $null
$GuiaNaranja = (C 232 110 40)
function Buscar-Control($padre, $texto) {
    foreach ($c in $padre.Controls) {
        if (-not $c.Visible) { continue }
        if ($c.Text -eq $texto) { return $c }
        $h = Buscar-Control $c $texto; if ($h) { return $h }
    }
    return $null
}
function Rect-Control($c) {
    $p = $form.PointToClient($c.PointToScreen([System.Drawing.Point]::Empty))
    return (New-Object System.Drawing.Rectangle($p.X, $p.Y, $c.Width, $c.Height))
}
# lo que hay que iluminar, en píxeles de la ventana
function Rect-Guia($que) {
    $Z = $script:K; $cw = $form.ClientSize.Width; $ch = $form.ClientSize.Height
    switch ($que) {
        'botones' { if ($script:grid) { return (Rect-Control $script:grid) } }
        'paginas' { $a = Buscar-Control $form '<'; $b = Buscar-Control $form '>'; if ($a -and $b) { return [System.Drawing.Rectangle]::Union((Rect-Control $a), (Rect-Control $b)) } }
        'skins' { $c = Buscar-Control $form 'Skins'; if ($c) { return (Rect-Control $c) } }
        'ajustes' { $c = Buscar-Control $form 'Ajustes'; if ($c) { return (Rect-Control $c) } }
        'personaje' { return (New-Object System.Drawing.Rectangle([int](404 * $Z), [int](56 * $Z), [int]($cw - 410 * $Z), [int]($ch - 62 * $Z))) }
        'barra' { return (New-Object System.Drawing.Rectangle(0, 0, $cw, [int](52 * $Z))) }
    }
    return [System.Drawing.Rectangle]::Empty
}
function Guia-Boton($texto, $accion, $fondo) {
    $b = New-Object System.Windows.Forms.Button; $b.Text = $texto; $b.FlatStyle = 'Flat'; $b.Tag = $accion; $b.Cursor = 'Hand'
    $b.Font = Fnt('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold); $b.ForeColor = [System.Drawing.Color]::White; $b.BackColor = $fondo
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::White; $b.FlatAppearance.BorderSize = [Math]::Max(1, [int](1.5 * $script:K))
    $b.FlatAppearance.MouseOverBackColor = (C 255 150 70)
    $b.Size = New-Object System.Drawing.Size([int](112 * $script:K), [int](26 * $script:K))
    $b.Add_Click({ & $this.Tag })
    $script:guia.Ov.Controls.Add($b); return $b
}
function Abrir-Guia {
    if ($script:guia -or (Ocupado) -or $form.WindowState -eq 'Minimized') { return }
    Fin-Discusion $true
    if ($script:modoSkins) { $script:modoSkins = $false; Mostrar-Pagina }
    if ($script:vAj -and -not $script:vAj.IsDisposed) { $script:vAj.Close() }
    $form.Refresh()
    # foto del panel: se ve detrás, oscurecida, con la parte que explica iluminada
    $foto = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
    $form.DrawToBitmap($foto, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
    $script:transicion = $true
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0); $ov.Size = $form.ClientSize; $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $script:guia = @{ Paso = 0; Pos = 0; Foto = $foto; Panda = (Cargar-Img 'skins\guia\panda.png'); Fase = 0.0; Rect = [System.Drawing.Rectangle]::Empty; Izq = $false; Ov = $ov }
    $ov.Add_Paint({ Pintar-Guia $_.Graphics })
    $ov.Add_MouseDown({ Guia-Avanzar })
    $script:guia.Sig = Guia-Boton 'Siguiente  ▶' { Guia-Avanzar } $GuiaNaranja
    $script:guia.Atras = Guia-Boton '◀  Atrás' { if ($script:guia.Paso -gt 0) { Guia-Paso ($script:guia.Paso - 1) } } (C 60 50 48)
    $script:guia.Saltar = Guia-Boton 'Saltar guía' { Cerrar-Guia } (C 40 36 36)
    $form.Controls.Add($ov); $ov.BringToFront()
    Guia-Paso 0
    $guiaTimer.Start()
}
# coloca al panda, el bocadillo y los botones en el lado contrario a lo que se ilumina
function Guia-Paso($n) {
    $e = $script:guia; $e.Paso = $n; $e.Pos = 0
    $e.Rect = Rect-Guia $PasosGuia[$n][0]
    $cw = $form.ClientSize.Width
    $e.Izq = (-not $e.Rect.IsEmpty) -and (($e.Rect.X + $e.Rect.Width / 2) -gt ($cw / 2))
    $Z = $script:K; $W = $cw / $Z; $H = $form.ClientSize.Height / $Z
    $x0 = if ($e.Izq) { 8 } else { $W - 352 }
    # los botones, uno debajo de otro, en el lado de dentro (al lado del panda)
    $bx = if ($e.Izq) { $x0 + 344 - 112 } else { $x0 }
    $i = 0
    foreach ($b in @($e.Sig, $e.Atras, $e.Saltar)) { $b.Location = New-Object System.Drawing.Point([int]($bx * $Z), [int](($H - 104 + $i * 32) * $Z)); $i++ }
    $ultimo = ($n -ge $PasosGuia.Count - 1)
    $e.Sig.Text = if ($ultimo) { '¡Entendido!' } else { 'Siguiente  ▶' }
    $e.Atras.Visible = ($n -gt 0); $e.Saltar.Visible = -not $ultimo
    $e.Ov.Invalidate()
}
function Guia-Avanzar {
    $e = $script:guia; if (-not $e) { return }
    $txt = $PasosGuia[$e.Paso][1]
    if ($e.Pos -lt $txt.Length) { $e.Pos = $txt.Length; $e.Ov.Invalidate(); return }   # primero termina de escribir
    if ($e.Paso -ge $PasosGuia.Count - 1) { Cerrar-Guia } else { Guia-Paso ($e.Paso + 1) }
}
function Cerrar-Guia {
    $e = $script:guia; if (-not $e) { return }
    $guiaTimer.Stop()
    $form.Controls.Remove($e.Ov); $e.Ov.Dispose()
    if ($e.Foto) { $e.Foto.Dispose() }; if ($e.Panda) { $e.Panda.Dispose() }
    $script:guia = $null; $script:transicion = $false
    $script:aj.Guia = $true; Guardar-Ajustes
    $form.Invalidate()
    Decir (Azar $script:skin.Hola) 'abiertos'
}
function Pintar-Guia($g) {
    $e = $script:guia; if (-not $e) { return }
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
    $cw = $e.Ov.Width; $ch = $e.Ov.Height
    $g.DrawImage($e.Foto, 0, 0, $e.Foto.Width, $e.Foto.Height)
    # todo oscuro menos lo que se explica, que se marca con un borde naranja que late
    $reg = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)))
    if (-not $e.Rect.IsEmpty) { $hueco = [System.Drawing.Rectangle]::Inflate($e.Rect, [int](4 * $script:K), [int](4 * $script:K)); $reg.Exclude($hueco) }
    $g.FillRegion((New-Object System.Drawing.SolidBrush((ARGB 175 0 0 0))), $reg); $reg.Dispose()
    if (-not $e.Rect.IsEmpty) {
        $al = [int](170 + 85 * [Math]::Sin($e.Fase * 1.6))
        $pen = New-Object System.Drawing.Pen((ARGB $al 255 150 60), [float](3 * $script:K))
        $g.DrawRectangle($pen, ($e.Rect.X - [int](4 * $script:K)), ($e.Rect.Y - [int](4 * $script:K)), ($e.Rect.Width + [int](8 * $script:K)), ($e.Rect.Height + [int](8 * $script:K))); $pen.Dispose()
    }
    # a partir de aquí, en las medidas del panel
    $g.ScaleTransform($script:K, $script:K)
    $W = $cw / $script:K; $H = $ch / $script:K
    $x0 = if ($e.Izq) { 8 } else { $W - 352 }
    # el panda asomando por abajo, moviéndose un poco
    $ph = 170; $pw = 220; $px = 0; $py = $H - 160 + [Math]::Sin($e.Fase) * 3
    if ($e.Panda) {
        $pw = $e.Panda.Width * $ph / $e.Panda.Height
        $px = if ($e.Izq) { $x0 } else { $x0 + 344 - $pw }
        if ($e.Izq) { $g.DrawImage($e.Panda, [float]($px + $pw), [float]$py, [float](-$pw), [float]$ph) } else { $g.DrawImage($e.Panda, [float]$px, [float]$py, [float]$pw, [float]$ph) }
    }
    # bocadillo con el texto que se va escribiendo
    $txt = $PasosGuia[$e.Paso][1]; $vis = $txt.Substring(0, [Math]::Min($txt.Length, $e.Pos))
    $f = FntP('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $alto = [Math]::Max(40, $g.MeasureString($txt, $f, 324).Height) + 30
    $by = 60; $bw = 344
    $tx = $px + $pw * 0.5; $bb = $by + $alto
    $r = Ruta-Redonda $x0 $by $bw $alto 12
    $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), (Ruta-Redonda ($x0 + 3) ($by + 4) $bw $alto 12))
    $g.FillPath([System.Drawing.Brushes]::White, $r)
    $pico = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($tx - 12), [float]($bb - 2))), (New-Object System.Drawing.PointF([float]($tx + 12), [float]($bb - 2))), (New-Object System.Drawing.PointF([float]$tx, [float]($bb + 14))))
    $g.FillPolygon([System.Drawing.Brushes]::White, $pico)
    $borde = New-Object System.Drawing.Pen($GuiaNaranja, 2.5); $borde.LineJoin = 'Round'
    $g.DrawPath($borde, $r); $g.DrawLines($borde, $pico); $r.Dispose(); $borde.Dispose()
    $g.FillRectangle([System.Drawing.Brushes]::White, [float]($tx - 11), [float]($bb - 4), 22, 4)
    $g.DrawString("PANDA ROJO  ·  $($e.Paso + 1)/$($PasosGuia.Count)", (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($GuiaNaranja)), [float]($x0 + 10), [float]($by + 6))
    $g.DrawString($vis, $f, (New-Object System.Drawing.SolidBrush((C 30 26 26))), (New-Object System.Drawing.RectangleF([float]($x0 + 10), [float]($by + 22), 324, [float]($alto - 24))))
}
$guiaTimer = New-Object System.Windows.Forms.Timer
$guiaTimer.Interval = 30
$guiaTimer.Add_Tick({
    $e = $script:guia; if (-not $e) { $guiaTimer.Stop(); return }
    $e.Fase += 0.12
    $txt = $PasosGuia[$e.Paso][1]; if ($e.Pos -lt $txt.Length) { $e.Pos = [Math]::Min($txt.Length, $e.Pos + 2) }
    $e.Ov.Invalidate()
})
# la primera vez: espera a que acaben el logo y la intro, y sale la guía
$script:guiaCalma = 0
$guiaInicio = New-Object System.Windows.Forms.Timer
$guiaInicio.Interval = 250
$guiaInicio.Add_Tick({
    if ($script:aj.Guia) { $guiaInicio.Stop(); return }
    if ((Ocupado) -or $script:discutiendo -or $form.WindowState -eq 'Minimized') { $script:guiaCalma = 0; return }
    $script:guiaCalma++
    if ($script:guiaCalma -ge 6) { $guiaInicio.Stop(); Abrir-Guia }
})

# ================= VENTANA DE AJUSTES =================
function Opacidad-Base {
    $o = if ($script:skin) { [double]$script:skin.Opacidad } else { 1.0 }
    return [Math]::Max(0.3, $o * $script:aj.Opacidad / 100.0)
}
function Iniciar-Con-Windows($si) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'c00lgui.lnk'
    try {
        if ($si) {
            if (-not (Test-Path $lnk)) {
                $sh = New-Object -ComObject WScript.Shell; $a = $sh.CreateShortcut($lnk)
                $a.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'; $a.Arguments = '"' + (Join-Path $Raiz 'c00lgui.vbs') + '"'
                $a.WorkingDirectory = $Raiz; $a.Save()
            }
        } elseif (Test-Path $lnk) { Remove-Item $lnk -Force }
    } catch {}
}
function Aplicar-Ajustes {
    $form.TopMost = $script:aj.Encima
    if ($script:vAj -and -not $script:vAj.IsDisposed) { $script:vAj.TopMost = $script:aj.Encima }
    $form.Opacity = (Opacidad-Base)
    switch ($script:aj.Charla) {
        'mucha' { $idleTimer.Interval = 9000; $idleTimer.Start() }
        'poca' { $idleTimer.Interval = 45000; $idleTimer.Start() }
        'nunca' { $idleTimer.Stop() }
        default { $idleTimer.Interval = 18000; $idleTimer.Start() }
    }
    Iniciar-Con-Windows $script:aj.Inicio
}
$script:vAj = $null
function Mostrar-Ajustes {
    if ($script:vAj -and -not $script:vAj.IsDisposed) { $script:vAj.Activate(); return }
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'Ajustes'; $f.FormBorderStyle = 'FixedToolWindow'; $f.StartPosition = 'Manual'; $f.ShowInTaskbar = $false
    $f.BackColor = (C 30 30 38); $f.ForeColor = (C 236 236 242); $f.Font = Fnt('Segoe UI', 9)
    $f.Owner = $form; $f.TopMost = $script:aj.Encima
    $script:ajF = $f; $script:ajY = 12
    $titulo = New-Object System.Windows.Forms.Label; $titulo.Text = 'AJUSTES DEL PANEL'; $titulo.Font = Fnt('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $titulo.ForeColor = (C 255 200 90); $titulo.Location = New-Object System.Drawing.Point(14, $script:ajY); $titulo.AutoSize = $true; $f.Controls.Add($titulo); $script:ajY += 34
    [void](Aj-Casilla 'Sonido activado' 'Sonido')
    [void](Aj-Barra 'Volumen' 'Volumen' 0 100)
    [void](Aj-Casilla 'Discusiones con invitados' 'Invitados')
    [void](Aj-Casilla 'Intros al cambiar de skin' 'Intros')
    [void](Aj-Casilla 'Modo seguro (epilepsia): sin destellos ni temblores' 'Epilepsia')
    $charla = Aj-Lista 'Frases solas' 'Charla' @('Muchas', 'Normal', 'Pocas', 'Nunca') @('mucha', 'normal', 'poca', 'nunca')
    $charla.Add_SelectedIndexChanged({ $script:aj[$this.Tag.Clave] = $this.Tag.Valores[$this.SelectedIndex]; Guardar-Ajustes; Aplicar-Ajustes })
    $tam = Aj-Lista 'Tamaño' 'Tamano' @('Pequeño', 'Normal', 'Grande', 'Enorme') @([double]1.0, [double]1.2, [double]1.5, [double]1.8)
    $tam.Add_SelectedIndexChanged({
        $nuevo = [double]$this.Tag.Valores[$this.SelectedIndex]
        if ($nuevo -eq $script:aj.Tamano -or (Ocupado)) { return }
        $script:aj.Tamano = $nuevo; Guardar-Ajustes
        $script:K = [float]($script:dpiBase * $nuevo)
        Construir-UI; Aplicar-Ajustes; Decir 'Tamaño cambiado.' 'abiertos'
    })
    [void](Aj-Barra 'Opacidad' 'Opacidad' 40 100)
    [void](Aj-Casilla 'Siempre encima de las demás ventanas' 'Encima')
    [void](Aj-Casilla 'Recordar dónde dejé la ventana' 'Posicion')
    [void](Aj-Casilla 'Abrir al encender el ordenador' 'Inicio')
    # personalizar los botones del panel (orden y botones propios) y su tutorial
    $bEd = Ventana-Boton 'Editar botones...' 16 ($script:ajY + 6) 170 { Mostrar-Editor-Botones } (C 255 200 90)
    $bTu = Ventana-Boton 'Tutorial' 196 ($script:ajY + 6) 118 { Mostrar-Tutorial } (C 90 90 110)
    $bEd.ForeColor = (C 20 20 24); $f.Controls.AddRange(@($bEd, $bTu)); $script:ajY += 42
    # la guía del panda rojo (la que sale la primera vez)
    $bGu = Ventana-Boton 'Guía del panda' 16 ($script:ajY + 2) 298 { $script:vAj.Close(); Abrir-Guia } $GuiaNaranja
    $bGu.ForeColor = [System.Drawing.Color]::White; $f.Controls.Add($bGu); $script:ajY += 38
    # skins archivadas: no salen en el menú Skins; solo se ponen desde aquí
    $bAr = Ventana-Boton "Skins archivadas ($(@($script:archivadas).Count))..." 16 ($script:ajY + 2) 298 { Mostrar-Archivadas } (C 70 70 90)
    $f.Controls.Add($bAr); $script:ajY += 38
    $cerrar = New-Object System.Windows.Forms.Button; $cerrar.Text = 'Cerrar'; $cerrar.FlatStyle = 'Flat'; $cerrar.BackColor = (C 60 60 74)
    $cerrar.Location = New-Object System.Drawing.Point(120, ($script:ajY + 6)); $cerrar.Size = New-Object System.Drawing.Size(90, 30)
    $cerrar.Add_Click({ $script:vAj.Close() }); $f.Controls.Add($cerrar)
    $f.ClientSize = New-Object System.Drawing.Size(330, ($script:ajY + 48))
    Escalar $f
    # al lado del panel, donde quepa
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $x = if ($form.Right + $f.Width + 8 -le $wa.Right) { $form.Right + 8 } else { [Math]::Max($wa.Left, $form.Left - $f.Width - 8) }
    $f.Location = New-Object System.Drawing.Point($x, [Math]::Max($wa.Top, [Math]::Min($form.Top, $wa.Bottom - $f.Height)))
    $script:vAj = $f
    $f.Show()
}
function Aj-Casilla($texto, $clave) {
    $c = New-Object System.Windows.Forms.CheckBox; $c.Text = $texto; $c.Checked = [bool]$script:aj[$clave]; $c.Tag = $clave
    $c.Location = New-Object System.Drawing.Point(16, $script:ajY); $c.Size = New-Object System.Drawing.Size(300, 24); $c.FlatStyle = 'Flat'
    $c.Add_CheckedChanged({ $script:aj[$this.Tag] = $this.Checked; Guardar-Ajustes; Aplicar-Ajustes })
    $script:ajF.Controls.Add($c); $script:ajY += 28; return $c
}
function Aj-Etiqueta($texto) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = $texto; $l.Location = New-Object System.Drawing.Point(16, ($script:ajY + 3)); $l.Size = New-Object System.Drawing.Size(120, 22)
    $script:ajF.Controls.Add($l)
}
function Aj-Lista($texto, $clave, $opciones, $valores) {
    Aj-Etiqueta $texto
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.DropDownStyle = 'DropDownList'; $cb.FlatStyle = 'Flat'
    $cb.Location = New-Object System.Drawing.Point(140, $script:ajY); $cb.Size = New-Object System.Drawing.Size(170, 24)
    foreach ($o in $opciones) { [void]$cb.Items.Add($o) }
    $idx = [Array]::IndexOf($valores, $script:aj[$clave]); if ($idx -lt 0) { $idx = 1 }; $cb.SelectedIndex = $idx
    $cb.Tag = @{ Clave = $clave; Valores = $valores }
    $script:ajF.Controls.Add($cb); $script:ajY += 32; return $cb
}
function Aj-Barra($texto, $clave, $min, $max) {
    Aj-Etiqueta $texto
    $tb = New-Object System.Windows.Forms.TrackBar; $tb.Minimum = $min; $tb.Maximum = $max; $tb.TickFrequency = 10; $tb.Value = [Math]::Max($min, [Math]::Min($max, [int]$script:aj[$clave]))
    $tb.Location = New-Object System.Drawing.Point(134, ($script:ajY - 2)); $tb.Size = New-Object System.Drawing.Size(182, 30); $tb.Tag = $clave
    $tb.Add_ValueChanged({ $script:aj[$this.Tag] = $this.Value; Guardar-Ajustes; Aplicar-Ajustes })
    $script:ajF.Controls.Add($tb); $script:ajY += 36; return $tb
}

# ================= SKINS ARCHIVADAS (Ajustes > Skins archivadas) =================
# Lista de las archivadas: ponerte una, devolverla al menú Skins o archivar otra.
$script:vAr = $null
function Mostrar-Archivadas {
    if ($script:vAr -and -not $script:vAr.IsDisposed) { $script:vAr.Activate(); return }
    $f = Nueva-Ventana 'Skins archivadas' 420 330; $f.StartPosition = 'CenterScreen'
    $t = Ventana-Texto 'SKINS ARCHIVADAS' 14 10 390; $t.Font = Fnt('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold); $t.ForeColor = (C 255 200 90)
    $ay = Ventana-Texto 'No salen en el menú Skins ni en las charlas con invitados. Conservan sus frases y opiniones.' 14 30 390 $true 34
    $lb = New-Object System.Windows.Forms.ListBox; $lb.Location = New-Object System.Drawing.Point(14, 68); $lb.Size = New-Object System.Drawing.Size(240, 150)
    $lb.BackColor = (C 20 20 26); $lb.ForeColor = (C 236 236 242); $lb.BorderStyle = 'FixedSingle'; $lb.IntegralHeight = $false
    $lb.Add_DoubleClick({ Ar-Poner })
    $script:arLb = $lb
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.DropDownStyle = 'DropDownList'; $cb.FlatStyle = 'Flat'
    $cb.Location = New-Object System.Drawing.Point(14, 260); $cb.Size = New-Object System.Drawing.Size(240, 24)
    $script:arCb = $cb
    $f.Controls.AddRange(@($t, $ay, $lb, $cb,
        (Ventana-Boton 'Ponerme esta skin' 266 68 140 { Ar-Poner } (C 255 200 90)),
        (Ventana-Boton 'Devolver al menú' 266 104 140 { Ar-Devolver }),
        (Ventana-Texto 'Archivar otra skin:' 14 238 240 $true),
        (Ventana-Boton 'Archivar' 266 257 140 { Ar-Archivar } (C 120 40 46)),
        (Ventana-Boton 'Cerrar' 266 294 140 { $script:vAr.Close() })))
    ($f.Controls | Where-Object { $_.Text -eq 'Ponerme esta skin' }).ForeColor = (C 20 20 24)
    Escalar $f
    $script:vAr = $f
    Ar-Refrescar
    $f.Show()
}
function Ar-Refrescar {
    $script:arLb.Items.Clear(); foreach ($n in $script:archivadas) { [void]$script:arLb.Items.Add($n) }
    if ($script:arLb.Items.Count) { $script:arLb.SelectedIndex = 0 }
    $script:arCb.Items.Clear(); foreach ($n in $Skins.Keys) { if (-not (Es-Archivada $n)) { [void]$script:arCb.Items.Add($n) } }
    if ($script:arCb.Items.Count) { $script:arCb.SelectedIndex = 0 }
    # el menú Skins cambia: si está abierto, se vuelve a dibujar
    if ($script:modoSkins) { Mostrar-Pagina }
}
function Ar-Poner {
    $n = [string]$script:arLb.SelectedItem; if (-not $n -or (Ocupado)) { return }
    $script:modoSkins = $false; Aplicar-Skin $n
}
function Ar-Devolver {
    $n = [string]$script:arLb.SelectedItem; if (-not $n) { return }
    $script:archivadas = @($script:archivadas | Where-Object { $_ -ne $n }); Guardar-Archivadas; Ar-Refrescar
}
function Ar-Archivar {
    $n = [string]$script:arCb.SelectedItem; if (-not $n) { return }
    $script:archivadas = @($script:archivadas) + $n; Guardar-Archivadas; Ar-Refrescar
}

# ================= EDITOR DE BOTONES (Ajustes > Editar botones) =================
# Cambia el orden de los botones del panel, añade los tuyos, edítalos o quítalos.
# Se trabaja sobre una copia ($script:edLista) y solo se guarda en botones.txt al pulsar Guardar.
$script:vEd = $null; $script:vTut = $null
function Ventana-Boton($texto, $x, $y, $w, $accion, $fondo) {
    $b = New-Object System.Windows.Forms.Button; $b.Text = $texto; $b.FlatStyle = 'Flat'; $b.Tag = $accion
    $b.BackColor = $(if ($fondo) { $fondo } else { (C 60 60 74) }); $b.FlatAppearance.BorderColor = (C 90 90 110)
    $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, 30)
    $b.Add_Click({ & $this.Tag })
    return $b
}
function Ventana-Texto($texto, $x, $y, $w, $gris, $alto = 20) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = $texto; $l.AutoSize = $false
    $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, $alto)
    if ($gris) { $l.ForeColor = (C 160 160 176) }
    return $l
}
function Nueva-Ventana($titulo, $w, $h) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $titulo; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.ShowInTaskbar = $false
    $f.BackColor = (C 30 30 38); $f.ForeColor = (C 236 236 242); $f.Font = Fnt('Segoe UI', 9); $f.TopMost = $script:aj.Encima
    $f.ClientSize = New-Object System.Drawing.Size($w, $h)
    return $f
}
# "roblox.com" -> "https://roblox.com"; los programas, rutas y enlaces especiales se dejan como están
function Normalizar-Destino($s) {
    $s = ([string]$s).Trim().Trim('"')
    if (-not $s) { return '' }
    if ($s -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or $s -match '^(\\|%|\.)') { return $s }
    if ($s -notmatch '\s' -and $s -match '^[\w-]+(\.[\w-]+)+(/.*)?$' -and $s -notmatch '\.(exe|bat|cmd|lnk|msc|txt|docx?|xlsx?|pptx?|pdf|png|jpe?g|gif|mp3|mp4|zip)$') { return "https://$s" }
    return $s
}
function Refrescar-Lista($sel) {
    $lb = $script:edLb; $lb.BeginUpdate(); $lb.Items.Clear()
    for ($i = 0; $i -lt $script:edLista.Count; $i++) { $b = $script:edLista[$i]; [void]$lb.Items.Add(('{0,2}.  {1}      ({2})' -f ($i + 1), $b.Nombre, $b.Abrir)) }
    $lb.EndUpdate()
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = [Math]::Max(0, [Math]::Min($sel, $lb.Items.Count - 1)) }
    $pags = [Math]::Max(1, [Math]::Ceiling($script:edLista.Count / $PorPagina))
    $script:edInfo.Text = "$($script:edLista.Count) botones  ·  $pags página(s) de $PorPagina"
}
function Mostrar-Editor-Botones {
    if ($script:vEd -and -not $script:vEd.IsDisposed) { $script:vEd.Activate(); return }
    $script:edLista = New-Object System.Collections.ArrayList
    foreach ($b in (Copiar-Botones $script:Botones)) { [void]$script:edLista.Add($b) }
    $f = Nueva-Ventana 'Editar botones' 470 420; $f.StartPosition = 'CenterScreen'
    $t = Ventana-Texto 'TUS BOTONES  (el de arriba es el primero del panel)' 14 10 440; $t.Font = Fnt('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold); $t.ForeColor = (C 255 200 90)
    $lb = New-Object System.Windows.Forms.ListBox; $lb.Location = New-Object System.Drawing.Point(14, 34); $lb.Size = New-Object System.Drawing.Size(300, 330)
    $lb.BackColor = (C 20 20 26); $lb.ForeColor = (C 236 236 242); $lb.BorderStyle = 'FixedSingle'; $lb.IntegralHeight = $false; $lb.HorizontalScrollbar = $true
    $lb.Add_DoubleClick({ Ed-Editar })
    $script:edLb = $lb
    $script:edInfo = Ventana-Texto '' 14 370 300 $true
    $x = 326; $w = 130
    $f.Controls.AddRange(@($t, $lb, $script:edInfo,
        (Ventana-Boton '▲  Subir' $x 34 $w { Ed-Mover -1 }),
        (Ventana-Boton '▼  Bajar' $x 70 $w { Ed-Mover 1 }),
        (Ventana-Boton '+  Añadir' $x 116 $w { Ed-Anadir } (C 40 110 60)),
        (Ventana-Boton 'Editar' $x 152 $w { Ed-Editar }),
        (Ventana-Boton 'Quitar' $x 188 $w { Ed-Quitar } (C 120 40 46)),
        (Ventana-Boton 'De serie' $x 234 $w { Ed-DeSerie }),
        (Ventana-Boton '?  Tutorial' $x 270 $w { Mostrar-Tutorial }),
        (Ventana-Boton 'Guardar' $x 326 $w { Ed-Guardar } (C 255 200 90)),
        (Ventana-Boton 'Cancelar' $x 362 $w { $script:vEd.Close() })))
    ($f.Controls | Where-Object { $_.Text -eq 'Guardar' }).ForeColor = (C 20 20 24)
    Escalar $f
    $script:vEd = $f
    Refrescar-Lista 0
    $f.Show()
}
function Ed-Mover($d) {
    $i = $script:edLb.SelectedIndex; $j = $i + $d
    if ($i -lt 0 -or $j -lt 0 -or $j -ge $script:edLista.Count) { return }
    $tmp = $script:edLista[$i]; $script:edLista[$i] = $script:edLista[$j]; $script:edLista[$j] = $tmp
    Refrescar-Lista $j
}
function Ed-Anadir {
    $n = Pedir-Boton $null
    if (-not $n) { return }
    # el botón nuevo va justo debajo del que está elegido (o al final)
    $i = $script:edLb.SelectedIndex
    if ($i -ge 0) { $script:edLista.Insert($i + 1, $n); Refrescar-Lista ($i + 1) } else { [void]$script:edLista.Add($n); Refrescar-Lista ($script:edLista.Count - 1) }
}
function Ed-Editar {
    $i = $script:edLb.SelectedIndex; if ($i -lt 0) { return }
    $n = Pedir-Boton $script:edLista[$i]
    if ($n) { $script:edLista[$i] = $n; Refrescar-Lista $i }
}
function Ed-Quitar {
    $i = $script:edLb.SelectedIndex; if ($i -lt 0) { return }
    $r = [System.Windows.Forms.MessageBox]::Show($script:vEd, "¿Quitar el botón '$($script:edLista[$i].Nombre)'?", 'Quitar botón', 'YesNo', 'Question')
    if ($r -eq 'Yes') { $script:edLista.RemoveAt($i); Refrescar-Lista $i }
}
function Ed-DeSerie {
    $r = [System.Windows.Forms.MessageBox]::Show($script:vEd, '¿Volver a los botones de serie? Se quitarán los tuyos y el orden que hayas puesto.', 'Botones de serie', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    $script:edLista.Clear(); foreach ($b in (Copiar-Botones $BotonesDeSerie)) { [void]$script:edLista.Add($b) }
    Refrescar-Lista 0
}
function Ed-Guardar {
    if ($script:edLista.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show($script:vEd, 'Tiene que quedar al menos un botón.', 'Guardar', 'OK', 'Information'); return }
    if (-not (Guardar-Botones $script:edLista)) { [void][System.Windows.Forms.MessageBox]::Show($script:vEd, 'No se ha podido guardar botones.txt.', 'Guardar', 'OK', 'Warning'); return }
    $script:Botones = Copiar-Botones $script:edLista
    Contar-Paginas; $script:pagina = 0
    if (-not $script:modoSkins -and -not $script:modoTienda) { Mostrar-Pagina }
    $script:vEd.Close()
    Decir '¡Botones guardados! Ya están en el panel, en tu orden.' 'abiertos'
}
# ventanita para crear o editar un botón; devuelve el botón o $null si se cancela
function Pedir-Boton($b) {
    $d = Nueva-Ventana $(if ($b) { 'Editar botón' } else { 'Botón nuevo' }) 400 316; $d.StartPosition = 'CenterParent'
    $script:pbN = New-Object System.Windows.Forms.TextBox; $script:pbA = New-Object System.Windows.Forms.TextBox; $script:pbW = New-Object System.Windows.Forms.TextBox
    foreach ($tb in @($script:pbN, $script:pbA, $script:pbW)) { $tb.BackColor = (C 20 20 26); $tb.ForeColor = (C 236 236 242); $tb.BorderStyle = 'FixedSingle'; $tb.Size = New-Object System.Drawing.Size(370, 24) }
    $script:pbN.Location = New-Object System.Drawing.Point(14, 34); $script:pbN.MaxLength = 30
    $script:pbA.Location = New-Object System.Drawing.Point(14, 92)
    $script:pbW.Location = New-Object System.Drawing.Point(14, 190)
    if ($b) { $script:pbN.Text = $b.Nombre; $script:pbA.Text = $b.Abrir; $script:pbW.Text = $b.Web }
    $ok = Ventana-Boton 'Aceptar' 174 272 100 { Pb-Aceptar $this.FindForm() } (C 255 200 90); $ok.ForeColor = (C 20 20 24)
    $no = Ventana-Boton 'Cancelar' 284 272 100 { $this.FindForm().DialogResult = 'Cancel' }
    $d.Controls.AddRange(@(
        (Ventana-Texto 'Nombre (lo que pone en el botón, mejor corto)' 14 12 370), $script:pbN,
        (Ventana-Texto 'Qué abre: una web, un programa, un archivo o una carpeta' 14 70 370), $script:pbA,
        (Ventana-Boton 'Archivo...' 14 122 110 { Pb-Archivo }),
        (Ventana-Boton 'Carpeta...' 132 122 110 { Pb-Carpeta }),
        (Ventana-Boton 'Probar' 274 122 110 { Pb-Probar } (C 40 110 60)),
        (Ventana-Texto 'Web por si el programa no está instalado (opcional)' 14 168 370), $script:pbW,
        (Ventana-Texto "Ejemplos:  roblox.com  ·  notepad.exe`n%USERPROFILE%\Downloads  ·  steam://rungameid/730" 14 222 370 $true 40),
        $ok, $no))
    $d.AcceptButton = $ok; $d.CancelButton = $no
    Escalar $d
    $dueno = if ($script:vEd -and -not $script:vEd.IsDisposed) { $script:vEd } else { $form }
    if ($d.ShowDialog($dueno) -ne 'OK') { $d.Dispose(); return $null }
    $res = @{ Nombre = $script:pbN.Text.Trim().Replace('|', '/'); Abrir = (Normalizar-Destino $script:pbA.Text).Replace('|', '/'); Web = (Normalizar-Destino $script:pbW.Text).Replace('|', '/') }
    $d.Dispose(); return $res
}
function Pb-Aceptar($d) {
    if (-not $script:pbN.Text.Trim()) { [void][System.Windows.Forms.MessageBox]::Show($d, 'Ponle un nombre al botón.', 'Falta el nombre', 'OK', 'Information'); $script:pbN.Focus(); return }
    if (-not $script:pbA.Text.Trim()) { [void][System.Windows.Forms.MessageBox]::Show($d, 'Escribe qué tiene que abrir (o usa Archivo... / Carpeta...).', 'Falta qué abre', 'OK', 'Information'); $script:pbA.Focus(); return }
    $d.DialogResult = 'OK'
}
function Pb-Archivo {
    $o = New-Object System.Windows.Forms.OpenFileDialog; $o.Title = 'Elige el programa o el archivo'
    $o.Filter = 'Programas y accesos directos|*.exe;*.lnk;*.bat;*.url|Todos los archivos|*.*'
    if ($o.ShowDialog() -eq 'OK') {
        $script:pbA.Text = $o.FileName
        if (-not $script:pbN.Text.Trim()) { $script:pbN.Text = [IO.Path]::GetFileNameWithoutExtension($o.FileName) }
    }
}
function Pb-Carpeta {
    $o = New-Object System.Windows.Forms.FolderBrowserDialog; $o.Description = 'Elige la carpeta que abrirá el botón'
    if ($o.ShowDialog() -eq 'OK') {
        $script:pbA.Text = $o.SelectedPath
        if (-not $script:pbN.Text.Trim()) { $script:pbN.Text = Split-Path $o.SelectedPath -Leaf }
    }
}
function Pb-Probar {
    $dest = Normalizar-Destino $script:pbA.Text
    if (-not $dest) { return }
    try { Start-Process ([Environment]::ExpandEnvironmentVariables($dest)) -ErrorAction Stop }
    catch { [void][System.Windows.Forms.MessageBox]::Show("No se ha podido abrir:`n$dest`n`nRevisa que esté bien escrito.", 'Probar', 'OK', 'Warning') }
}

# ================= TUTORIAL (una hoja en blanco) =================
# Una hoja de cuaderno con los pasos para personalizar los botones. El texto se dibuja sobre la hoja,
# encima de sus rayas; si no cabe, la hoja se mueve con la rueda del ratón.
# Para cambiar el tutorial, edita la lista $TextoTutorial: cada línea es @('tipo', 'texto').
# Tipos: titulo, paso, normal, codigo, nota y hueco (línea en blanco). Cada línea empieza por una coma (para que PowerShell no junte las líneas).
$TextoTutorial = @(
    , @('titulo', 'Cómo poner tus propios botones')
    , @('normal', 'Puedes cambiar el orden de los botones del panel y añadir los tuyos: páginas web, programas, juegos, archivos o carpetas.')
    , @('hueco', '')
    , @('paso', '1. Abre el editor')
    , @('normal', 'Pulsa el botón Ajustes (arriba del panel) y luego "Editar botones...". Verás la lista de todos tus botones, en orden.')
    , @('hueco', '')
    , @('paso', '2. Cambia el orden')
    , @('normal', 'Haz clic en un botón de la lista y pulsa ▲ Subir o ▼ Bajar. El de arriba del todo es el primero del panel. En cada página caben 12 botones; los demás pasan a la siguiente (con < y >).')
    , @('hueco', '')
    , @('paso', '3. Añade un botón tuyo')
    , @('normal', 'Pulsa + Añadir y rellena:')
    , @('normal', '•  Nombre: lo que pondrá en el botón. Mejor corto (unas 12 letras).')
    , @('normal', '•  Qué abre: puede ser...')
    , @('codigo', 'una web:          roblox.com')
    , @('codigo', 'un programa:      notepad.exe   (o "Archivo...")')
    , @('codigo', 'una carpeta:      %USERPROFILE%\Downloads')
    , @('codigo', 'un juego Steam:   steam://rungameid/730')
    , @('normal', '•  Web por si no está instalado: opcional. Si el programa no está en el ordenador, se abre esta web.')
    , @('normal', 'Pulsa Probar para comprobar que abre lo que quieres, y luego Aceptar.')
    , @('nota', 'El botón nuevo aparece debajo del que tenías elegido en la lista.')
    , @('hueco', '')
    , @('paso', '4. Edita o quita botones')
    , @('normal', 'Elige uno y pulsa Editar (o haz doble clic) para cambiarlo, o Quitar para borrarlo.')
    , @('hueco', '')
    , @('paso', '5. Guarda')
    , @('normal', 'Pulsa Guardar y el panel se actualiza al momento. Si pulsas Cancelar, no cambia nada.')
    , @('hueco', '')
    , @('paso', '¿Te has liado?')
    , @('normal', 'Pulsa "De serie" en el editor y vuelven los botones de siempre (YouTube, Word, Excel...).')
    , @('hueco', '')
    , @('paso', 'Truco: con el Bloc de notas')
    , @('normal', 'Tus botones se guardan en botones.txt, en la carpeta del panel. Ábrelo con el Bloc de notas: una línea por botón, así:')
    , @('codigo', 'Nombre | qué abre | web si no está')
    , @('codigo', 'YouTube | https://www.youtube.com')
    , @('codigo', 'Discord | discord: | https://discord.com/app')
    , @('codigo', 'Descargas | %USERPROFILE%\Downloads')
    , @('nota', 'Si borras botones.txt, vuelven los botones de serie. Cierra y abre el panel para ver los cambios hechos a mano.')
)
function Tut-Fuente($tipo) {
    switch ($tipo) {
        'titulo' { return (Fnt('Segoe Print', 15, [System.Drawing.FontStyle]::Bold)) }
        'paso' { return (Fnt('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)) }
        'codigo' { return (Fnt('Consolas', 9.5)) }
        'nota' { return (Fnt('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)) }
        default { return (Fnt('Segoe UI', 10)) }
    }
}
function Tut-Color($tipo) {
    switch ($tipo) { 'titulo' { return (C 30 40 120) } 'paso' { return (C 200 30 60) } 'codigo' { return (C 20 90 150) } 'nota' { return (C 110 110 120) } default { return (C 30 30 36) } }
}
# coloca cada línea en la hoja (en píxeles) y devuelve el alto total
function Tut-Maquetar($papel) {
    $Z = $script:K; $g = $papel.CreateGraphics()
    $x = 56 * $Z; $ancho = $papel.Width - $x - 18 * $Z; $y = 16 * $Z
    $script:tutPos = New-Object System.Collections.ArrayList
    foreach ($l in $TextoTutorial) {
        $tipo = $l[0]; $txt = $l[1]
        if ($tipo -eq 'hueco') { $y += 10 * $Z; continue }
        $f = Tut-Fuente $tipo
        $xx = if ($tipo -eq 'codigo') { $x + 16 * $Z } else { $x }
        $h = $g.MeasureString($txt, $f, [int]($ancho - ($xx - $x))).Height
        [void]$script:tutPos.Add(@{ T = $txt; K = $tipo; F = $f; R = (New-Object System.Drawing.RectangleF([float]$xx, [float]$y, [float]($ancho - ($xx - $x)), [float]($h + 2))) })
        $y += $h + $(if ($tipo -in @('titulo', 'paso')) { 4 * $Z } else { 2 * $Z })
    }
    $g.Dispose()
    return [int]($y + 20 * $Z)
}
function Mostrar-Tutorial {
    if ($script:vTut -and -not $script:vTut.IsDisposed) { $script:vTut.Activate(); return }
    $f = Nueva-Ventana 'Tutorial: tus botones' 520 500; $f.StartPosition = 'CenterScreen'; $f.BackColor = (C 206 198 186)
    # marco con barra de desplazamiento y, dentro, la hoja de papel
    $marco = New-Object System.Windows.Forms.Panel; $marco.Location = New-Object System.Drawing.Point(16, 14); $marco.Size = New-Object System.Drawing.Size(488, 434)
    $marco.BackColor = [System.Drawing.Color]::White; $marco.AutoScroll = $true
    $papel = New-Object System.Windows.Forms.Panel; $papel.Location = New-Object System.Drawing.Point(0, 0); $papel.Size = New-Object System.Drawing.Size(468, 434); $papel.BackColor = [System.Drawing.Color]::White
    Doble-Buffer $papel
    $papel.Add_Paint({
        $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'; $Z = $script:K
        # rayas azules, margen rojo y agujeros de cuaderno
        $lin = New-Object System.Drawing.Pen((C 205 222 242), [float]$Z)
        for ($yy = 30 * $Z; $yy -lt $this.Height; $yy += 22 * $Z) { $g.DrawLine($lin, 0, [float]$yy, [float]$this.Width, [float]$yy) }
        $lin.Dispose()
        $g.DrawLine((New-Object System.Drawing.Pen((C 236 120 130), [float](1.5 * $Z))), [float](42 * $Z), 0, [float](42 * $Z), [float]$this.Height)
        for ($yy = 110 * $Z; $yy -lt $this.Height; $yy += 260 * $Z) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 206 198 186))), [float](14 * $Z), [float]$yy, [float](16 * $Z), [float](16 * $Z)) }
        foreach ($p in $script:tutPos) {
            if ($p.K -eq 'codigo') { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 238 244 252))), [float]($p.R.X - 6 * $Z), $p.R.Y, [float]($p.R.Width + 6 * $Z), $p.R.Height) }
            $g.DrawString($p.T, $p.F, (New-Object System.Drawing.SolidBrush((Tut-Color $p.K))), $p.R)
        }
    })
    $marco.Controls.Add($papel)
    # la rueda del ratón mueve la hoja aunque el ratón esté encima del papel
    $papel.Add_MouseEnter({ $this.Parent.Focus() })
    $cer = Ventana-Boton 'Cerrar' 404 460 100 { $script:vTut.Close() }
    $edi = Ventana-Boton 'Abrir el editor' 254 460 140 { Mostrar-Editor-Botones } (C 255 200 90); $edi.ForeColor = (C 20 20 24)
    $f.Controls.AddRange(@($marco, $cer, $edi))
    Escalar $f
    # la hoja ocupa todo el ancho (menos la barra) y tan alta como el texto
    $papel.Width = $marco.ClientSize.Width - [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
    $papel.Height = [Math]::Max($marco.ClientSize.Height, (Tut-Maquetar $papel))
    $script:vTut = $f
    $f.Show()
}

function Aplicar-Skin($nombre) {
    if (Ocupado) { return }
    $prev = $script:skinNombre
    Set-Content -Path $ArchivoSkin -Value $nombre -Encoding UTF8
    $script:modoSkins = $false
    if ($nombre -eq $prev) { Mostrar-Pagina; return }
    if ($Skins[$nombre].Estilo -eq 'hacker') {
        # el panel "se rompe" y renace como c00lgui
        Glitch 14 @{ Skin = $nombre; Prev = $prev }
    } else {
        $script:skinNombre = $nombre
        Construir-UI
        Efecto-Entrada $prev
    }
}

# ================= VENTANA =================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'c00lgui'
$form.FormBorderStyle = 'None'
$form.StartPosition = 'CenterScreen'
Doble-Buffer $form

$form.Add_Paint({
    $k = $script:skin; $g = $_.Graphics
    $g.ScaleTransform($script:K, $script:K)
    $W = [int]($form.ClientSize.Width / $script:K); $H = [int]($form.ClientSize.Height / $script:K)
    switch ($k.Estilo) {
        'web' {
            $g.SmoothingMode = 'AntiAlias'
            $rect = New-Object System.Drawing.Rectangle(0, 0, $W, 52)
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $k.Barra1, $k.Barra2, 90)
            $g.FillRectangle($br, $rect); $br.Dispose()
            # icono "i" amarillo, como el de la camiseta de SeaDrive
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 198 26))), 12, 11, 30, 30)
            $g.DrawEllipse((New-Object System.Drawing.Pen((C 20 20 20), 2)), 12, 11, 30, 30)
            $g.DrawString('i', (FntP('Georgia', 15, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 20, 12)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 140 220 60))), 0, 52, $W, 4)
            # barra del navegador
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 244 246 249))), 0, 56, $W, 32)
            $g.DrawLine((New-Object System.Drawing.Pen((C 200 205 212), 1)), 0, 88, $W, 88)
            $g.DrawString('◀   ▶   ⟳', (FntP('Segoe UI Symbol', 10)), (New-Object System.Drawing.SolidBrush((C 90 100 115))), 10, 61)
            $g.FillRectangle([System.Drawing.Brushes]::White, 96, 60, ($W - 112), 24)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 185 195 205), 1)), 96, 60, ($W - 112), 24)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, $H - 10, $W, 10)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, $H - 7, $W, 2)
        }
        'tele' {
            $g.SmoothingMode = 'AntiAlias'
            $lun = New-Object System.Drawing.SolidBrush((C 255 95 70))
            for ($y = 64; $y -lt $H; $y += 22) { for ($x = (($y / 22) % 2) * 11; $x -lt $W; $x += 22) { $g.FillEllipse($lun, $x, $y, 7, 7) } }
            $lun.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 58 44 190))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 225 50))), 0, 52, $W, 5)
            $g.DrawString($k.Titulo, (FntP($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 15, 9)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 4)
            $g.DrawLine($pen, 472, 66, 454, 48); $g.DrawLine($pen, 538, 66, 556, 48)
            $g.FillEllipse([System.Drawing.Brushes]::Black, 446, 41, 12, 12); $g.FillEllipse([System.Drawing.Brushes]::Black, 552, 41, 12, 12)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $rx = 402; $ry = 64; $rw = 206; $rh = 170; $rr = 26
            $path.AddArc($rx, $ry, $rr, $rr, 180, 90); $path.AddArc($rx + $rw - $rr, $ry, $rr, $rr, 270, 90)
            $path.AddArc($rx + $rw - $rr, $ry + $rh - $rr, $rr, $rr, 0, 90); $path.AddArc($rx, $ry + $rh - $rr, $rr, $rr, 90, 90); $path.CloseFigure()
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 58 44 190))), $path); $g.DrawPath($pen, $path); $path.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 225 50))), 420, 214, 12, 12); $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), 420, 214, 12, 12)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 90 220 245))), 438, 214, 12, 12); $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), 438, 214, 12, 12)
            $g.DrawString('CH 03', (FntP('Comic Sans MS', 8, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 548, 213)
            $pen.Dispose()
            $arco = @((C 255 40 40), (C 255 150 30), (C 255 225 50), (C 90 210 80), (C 90 220 245), (C 58 44 190), (C 230 80 200))
            $bw = [Math]::Ceiling($W / $arco.Count)
            for ($i = 0; $i -lt $arco.Count; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($arco[$i])), ($i * $bw), ($H - 10), $bw, 10) }
        }
        'gunsaw' {
            # pantalla CRT morada del menú de personajes de Gunsaw
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($k.Fondo)), 0, 0, $W, $H)
            $lin = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, 255, 255, 255), 1)
            for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($lin, 0, $y, $W, $y) }
            $lin.Dispose()
            $g.SmoothingMode = 'AntiAlias'
            $gris = New-Object System.Drawing.Pen((C 125 112 130), 1)
            $g.DrawString('A-D to switch skins', (FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 200 195 205))), 180, 6)
            $g.DrawLine($gris, 12, 56, ($W - 12), 56)
            $g.DrawRectangle($gris, 409, 61, 191, 151)
            $g.DrawString('Character', (FntP('Consolas', 9, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 205 200 210))), 408, 215)
            # caja de estadísticas
            $g.DrawRectangle($gris, 16, 276, 376, 24)
            if ($k.Hambre) {
                Texto-Marcado $g "Aim {g}135%{b}  Health {r}90{b}  HAMBRE" (FntP('Consolas', 8.5, [System.Drawing.FontStyle]::Bold)) 22 281
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 50 36 28))), 248, 282, 136, 12)
                $colH = if ($script:hambre -ge 100) { (C 230 40 40) } else { $k.Acento }
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($colH)), 248, 282, [int](136 * $script:hambre / 100), 12)
                $g.DrawRectangle($gris, 248, 282, 136, 12)
            } else {
                Texto-Marcado $g "Aim {r}90%{b}  Move {r}93%{b}  Health {g}120{b}  Telarañas: {r}$($script:telas)" (FntP('Consolas', 8.5, [System.Drawing.FontStyle]::Bold)) 22 281
            }
            $gris.Dispose()
            if ($k.Agua) {
                # agua con olas animadas bajo Dune
                $pts = New-Object System.Collections.ArrayList
                for ($x = 0; $x -le $W; $x += 8) { [void]$pts.Add((New-Object System.Drawing.PointF($x, [float](304 + [Math]::Sin($x / 26.0 + $script:fase) * 3)))) }
                [void]$pts.Add((New-Object System.Drawing.PointF($W, $H))); [void]$pts.Add((New-Object System.Drawing.PointF(0, $H)))
                $g.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 60, 150, 170))), [System.Drawing.PointF[]]$pts.ToArray())
            }
            # marco redondeado del monitor
            $marco = Ruta-Redonda 2 2 ($W - 4) ($H - 4) 26
            $g.DrawPath((New-Object System.Drawing.Pen((C 10 4 12), 6)), $marco); $marco.Dispose()
        }
        'mlg' {
            $g.SmoothingMode = 'AntiAlias'
            # degradado azul -> rojo de PURSUITCORE con rayas diagonales
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (C 57 72 191), (C 229 45 45), 35)
            $g.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
            $ray = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(22, 255, 255, 255), 10)
            for ($x = -$H; $x -lt $W; $x += 34) { $g.DrawLine($ray, $x, $H, ($x + $H), 0) }
            $ray.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 14 14 28))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 255 0))), 0, 52, $W, 3)
            if ($script:imgs.titulo) { $g.DrawImage($script:imgs.titulo, 8, 4, 150, 47) }
            # marco lima del retrato
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 255 0), 3)), 408, 60, 193, 153)
            # barra de carga del Snipe
            $g.FillRectangle([System.Drawing.Brushes]::Black, 410, 216, 190, 10)
            if ($script:snApuntando) {
                $c = if ($script:snCarga -ge 60) { [System.Drawing.Color]::Red } elseif ($script:snCarga -ge 20) { [System.Drawing.Color]::Yellow } else { [System.Drawing.Color]::White }
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), 410, 216, [int](190 * [Math]::Min(1.0, $script:snCarga / 60.0)), 10)
            }
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 255 0), 1)), 410, 216, 190, 10)
            $g.DrawString("HITMARKERS: $($script:hitsTotal)    DO THE DEW: $($script:dew)", (FntP('Arial Black', 8)), (New-Object System.Drawing.SolidBrush((C 191 239 255))), 16, 280)
        }
        { $_ -in @('culto', 'kaiju', 'zorro', 'mew', 'oeste', 'pressure', 'dod', 'teto', 'femta', 'pop', 'pizza', 'punk', 'enfosi', 'gran', 'abismo', 'historia', 'lobo', 'arana', 'clima', 'pintor', 'evil', 'niebla', 'knight', 'boneyard', 'corrupta') } {
            # skins nuevas: fondo real + personajes grandes + efectos + bocadillo propio
            $g.SmoothingMode = 'AntiAlias'
            # el fondo se prepara siempre con el tamaño fijo de la skin (no con el de la ventana a medio montar)
            if (-not $script:bmpEscena) { $script:bmpEscena = Fondo-Escena $k $k.Ancho $k.Alto }
            $g.DrawImage($script:bmpEscena, 0, 0, $k.Ancho, $k.Alto)
            if ($k.Estilo -eq 'kaiju' -and $script:kFase.P -and -not $script:kFin) {
                $gl = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(400, 120, ($W - 400), 140)), [System.Drawing.Color]::FromArgb(0, 255, 120, 30), [System.Drawing.Color]::FromArgb(120, 255, 90, 20), 90)
                $g.FillRectangle($gl, 400, 121, ($W - 400), 138); $gl.Dispose()
            }
            Pintar-Actores $g
            switch ($k.Estilo) {
                'culto' {
                    # ritual: todo se tiñe de rojo y salen tentáculos del suelo
                    if ($script:ritualFx -gt 0) {
                        $a = [int]([Math]::Min(1.0, $script:ritualFx / 20.0) * 110)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 160, 0, 20))), 0, 0, $W, $H)
                        $alto = [Math]::Sin([Math]::Min(1.0, (44 - $script:ritualFx) / 14.0) * [Math]::PI / 2) * 150
                        $ten = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 34, 10, 34), 11); $ten.StartCap = 'Round'; $ten.EndCap = 'Round'
                        $ten2 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 120, 40, 120), 4); $ten2.StartCap = 'Round'; $ten2.EndCap = 'Round'
                        foreach ($tx in @(30, 140, 260, 420, 520, 640, 730)) {
                            $o = [Math]::Sin($script:fase * 2 + $tx) * 22
                            foreach ($pn in @($ten, $ten2)) { $g.DrawBezier($pn, [float]$tx, [float]$H, [float]($tx + $o), [float]($H - $alto * 0.4), [float]($tx - $o), [float]($H - $alto * 0.7), [float]($tx + $o * 1.5), [float]($H - $alto)) }
                        }
                        $ten.Dispose(); $ten2.Dispose()
                    }
                    # fe del culto y seguidores
                    Texto-Contorno $g 'FE' 'Palatino Linotype' 15 14 274 (C 238 206 120) 3
                    $marco = Ruta-Redonda 46 279 210 15 10
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 40 14 18))), $marco)
                    if ($script:fe -gt 0) {
                        $col1 = if ($script:fe -lt 25) { (C 110 110 110) } else { (C 170 24 34) }; $col2 = if ($script:fe -lt 25) { (C 160 160 160) } else { (C 236 190 70) }
                        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(46, 279, 210, 15)), $col1, $col2, 0)
                        $g.FillRectangle($br, 48, 281, [int](206 * $script:fe / 100), 11); $br.Dispose()
                    }
                    $g.DrawPath((New-Object System.Drawing.Pen((C 214 170 60), 2)), $marco); $marco.Dispose()
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 176 128 214))), 272, 280, 13, 13)
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 176 128 214))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(272, 284)), (New-Object System.Drawing.PointF(271, 276)), (New-Object System.Drawing.PointF(277, 281))))
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 176 128 214))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(285, 284)), (New-Object System.Drawing.PointF(286, 276)), (New-Object System.Drawing.PointF(280, 281))))
                    Texto-Contorno $g "$($script:seguidores) seguidores" 'Palatino Linotype' 14 290 275 (C 226 200 250) 3
                }
                'kaiju' {
                    Pintar-Particulas $g
                    Vida-Kaiju $g 'PYROPHINA' $script:kHP.P 420 62 156 (C 240 90 30) $script:kFase.P
                    Vida-Kaiju $g 'ZARATANA' $script:kHP.Z 590 62 156 (C 150 140 210) $script:kFase.Z
                    if ([Math]::Floor($script:fase * 1.5) % 2 -eq 0) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 240 30 30))), 16, 283, 10, 10) }
                    Texto-Contorno $g 'EN DIRECTO' 'EdmundMcMillen_INTLv4' 15 32 277 (C 255 214 60) 3
                    Texto-Contorno $g "COLLARES  Pyrophina $($script:collares.P)  ·  Zaratana $($script:collares.Z)" 'EdmundMcMillen_INTLv4' 13 140 279 (C 255 236 200) 3
                }
                'zorro' {
                    $g.DrawString('ANTOJO DE SÁNDWICH', (FntP('Trebuchet MS', 8.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 246 230))), 15, 279)
                    $g.DrawString('ANTOJO DE SÁNDWICH', (FntP('Trebuchet MS', 8.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 110 60 30))), 14, 278)
                    $marco = Ruta-Redonda 170 281 170 13 10
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 236 214))), $marco)
                    if ($script:antojo -gt 0) {
                        $colA = if ($script:antojo -ge 100) { (C 220 60 60) } else { (C 236 140 60) }
                        $relleno = Ruta-Redonda 171 282 ([Math]::Max(10, 168 * $script:antojo / 100)) 11 10
                        $g.FillPath((New-Object System.Drawing.SolidBrush($colA)), $relleno); $relleno.Dispose()
                    }
                    $g.DrawPath((New-Object System.Drawing.Pen((C 150 80 40), 2)), $marco); $marco.Dispose()
                    Dibujar-Sandwich $g 370 274 0.8
                }
                'femta' {
                    # palabras de canciones de femtanyl que saltan por la pantalla
                    foreach ($pw in $script:tkPal) {
                        $st = $g.Save(); $g.TranslateTransform([float]$pw.X, [float]$pw.Y); $g.RotateTransform([float]$pw.Rot)
                        $al = [int][Math]::Min(255, $pw.T * 14)
                        Texto-Color $g $pw.Txt 'Arial Black' 20 3 0 (ARGB ([int]($al * 0.6)) 40 230 255) (ARGB 0 0 0 0) 1
                        Texto-Color $g $pw.Txt 'Arial Black' 20 0 0 (ARGB $al 255 255 255) (ARGB $al 230 20 40) 4
                        $g.Restore($st)
                    }
                    # modo breakcore: franjas de glitch por todo el panel
                    if ($script:tkFx -gt 0) {
                        for ($i = 0; $i -lt 7; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((ARGB 150 230 20 40), (ARGB 110 255 255 255), (ARGB 110 40 230 255), (ARGB 200 0 0 0))[$Rnd.Next(4)])), $Rnd.Next(-60, $W), $Rnd.Next(0, $H), $Rnd.Next(60, 400), $Rnd.Next(2, 9)) }
                        if ($script:tkFx % 6 -lt 3) { Texto-Color $g 'BREAKCORE MODE' 'Arial Black' 18 470 66 (C 255 255 255) (C 230 20 40) 4 }
                    }
                    # la canción de la portada que se ve
                    $tc = "♪ $($TokenCanciones[$script:tkCd - 1])"; $tw = Ancho-Texto $tc 'Arial Black' 11
                    $g.FillRectangle([System.Drawing.Brushes]::Black, [float](572 - $tw / 2 - 6), 250, [float]($tw + 12), 20)
                    Texto-Color $g $tc 'Arial Black' 11 (572 - $tw / 2) 252 (C 255 255 255) (C 230 20 40) 1
                    # fichas y barra de HYPE
                    Texto-Color $g "TOKENS: $($script:tkFichas)" 'Consolas' 15 16 284 (C 255 255 255) (C 230 20 40) 3
                    $bpm = 174 + [int]($script:tkHype * 0.66) + $(if ($script:tkFx -gt 0) { 66 } else { 0 })
                    Texto-Color $g "BPM $bpm" 'Consolas' 15 150 284 (C 255 60 70) (C 0 0 0) 3
                    Texto-Color $g 'HYPE' 'Consolas' 12 248 286 (C 255 255 255) (C 0 0 0) 3
                    for ($i = 0; $i -lt 5; $i++) {
                        $lleno = $script:tkHype -ge ($i + 1) * 20 - 10 -or $script:tkFx -gt 0
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($lleno) { (C 230 20 40) } else { (C 50 20 24) }))), (290 + $i * 20), 287, 16, 14)
                        $g.DrawRectangle((New-Object System.Drawing.Pen((C 255 255 255), 1)), (290 + $i * 20), 287, 16, 14)
                    }
                }
                'punk' {
                    # su reproductor, su estudio, su canal y el ampli (Ky-Pintar)
                    Ky-Pintar $g $W $H $k
                }
                'pizza' {
                    # la pizza de Kevin en su plato (o el plato vacío esperando al repartidor)
                    Dibujar-Pizza $g $PizzaX $PizzaY $PizzaR $script:pzTrozos $script:pzQueso
                    if ($script:pzTrozos -le 0 -and ([Math]::Floor([Environment]::TickCount / 400) % 2 -eq 0)) {
                        Texto-Contorno $g 'PIZZA EN' 'Comic Sans MS' 11 ($PizzaX - 30) ($PizzaY - 18) (C 255 110 200) 3
                        Texto-Contorno $g 'CAMINO...' 'Comic Sans MS' 11 ($PizzaX - 32) ($PizzaY - 2) (C 255 110 200) 3
                    }
                    # rabia: el lienzo se pone rojo y el borde arde
                    if ($script:pzFx -gt 0) {
                        $al = [int]([Math]::Min(1.0, $script:pzFx / 20.0) * (60 + [Math]::Sin($script:fase * 3) * 30))
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 230, 30, 0))), 414, 90, 334, 172)
                        $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([Math]::Min(255, $al * 3), 255, 140, 0), 4)), 412, 88, 338, 176)
                    }
                    # trozos de pizza (o brasas) cayendo
                    foreach ($t in $script:pzLluvia) {
                        if ($t.Fuego) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 200 255 ([int](120 + ($t.A % 100))) 0))), [float]$t.X, [float]$t.Y, 6, 9) }
                        else { Dibujar-Trozo $g $t.X $t.Y 18 $t.A }
                    }
                    # el grito: DON'T TOUCH MY PIZZA!
                    if ($script:pzGrito) {
                        $q = 30 - $script:pzGrito.T; $esc = if ($q -lt 4) { 0.4 + $q * 0.2 } else { 1.0 }
                        $al = [int][Math]::Min(255, $script:pzGrito.T * 20)
                        $st = $g.Save(); $g.TranslateTransform([float](580 + $Rnd.Next(-3, 4)), [float](120 + $Rnd.Next(-2, 3))); $g.RotateTransform(-6); $g.ScaleTransform([float]$esc, [float]$esc)
                        $tw = Ancho-Texto $script:pzGrito.Txt 'Impact' 30
                        Texto-Color $g $script:pzGrito.Txt 'Impact' 30 (-$tw / 2) (-20) (ARGB $al 230 30 30) (ARGB $al 255 255 255) 8
                        $g.Restore($st)
                    }
                    # pizzas comidas, trozos que quedan y barra de enfado
                    Texto-Contorno $g "PIZZAS: $($script:pzComidas)" 'Comic Sans MS' 13 16 278 (C 70 200 40) 4
                    for ($i = 0; $i -lt 8; $i++) {
                        if ($i -lt $script:pzTrozos) { Dibujar-Trozo $g (134 + $i * 14) 293 12 180 }
                        else { $g.DrawPolygon((New-Object System.Drawing.Pen((ARGB 120 60 60 60), 1)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float](134 + $i * 14), 286)), (New-Object System.Drawing.PointF([float](128 + $i * 14), 299)), (New-Object System.Drawing.PointF([float](140 + $i * 14), 299)))) }
                    }
                    Texto-Contorno $g 'ENFADO' 'Comic Sans MS' 11 250 281 (C 230 40 40) 3
                    $g.FillRectangle([System.Drawing.Brushes]::White, 310, 285, 86, 12)
                    if ($script:pzEnfado -gt 0) {
                        $colE = if ($script:pzFx -gt 0) { @((C 255 140 0), (C 230 30 30))[[int]($script:fase * 2) % 2] } else { (C 230 40 40) }
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($colE)), 310, 285, [int](86 * $script:pzEnfado / 100), 12)
                    }
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 20 20 20), 2)), 310, 285, 86, 12)
                }
                'pop' {
                    $tt = [Environment]::TickCount / 1000.0
                    # brillos que tiemblan en la superficie del agua
                    $bri = New-Object System.Drawing.SolidBrush((ARGB 46 255 255 255))
                    for ($i = 0; $i -lt 6; $i++) { $sx = 406 + (($tt * 14 + $i * 61) % 350); $g.FillEllipse($bri, [float]$sx, [float](60 + ($i % 3) * 5 + [Math]::Sin($tt * 2 + $i) * 2), 46, 5) }
                    $bri.Dispose()
                    # burbujas que suben
                    $pb2 = New-Object System.Drawing.Pen((ARGB 170 230 245 255), 1)
                    foreach ($bu in $script:burbujas) { $bx = $bu.X + [Math]::Sin($bu.F) * 3; $g.DrawEllipse($pb2, [float]($bx - $bu.R), [float]($bu.Y - $bu.R), [float](2 * $bu.R), [float](2 * $bu.R)); $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), [float]($bx - $bu.R * 0.4), [float]($bu.Y - $bu.R * 0.6), [float]($bu.R * 0.5), [float]($bu.R * 0.5)) }
                    $pb2.Dispose()
                    # los bancos de tetras neón
                    $g.SetClip((New-Object System.Drawing.RectangleF(406, 58, [float]($W - 408), [float]($H - 60))))
                    foreach ($pz in $script:peces) { Dibujar-Tetra-Pez $g $pz.X ($pz.Y + [Math]::Sin($pz.F) * 2) ($pz.E * [Math]::Sign($pz.V)) $pz.F }
                    $g.ResetClip()
                    # Tetra otra vez por encima: los peces nadan detrás de ella
                    $ae = $script:actores['E']; if ($ae) { $mi = $g.InterpolationMode; $g.InterpolationMode = 'HighQualityBilinear'; Pintar-Actor $g $ae; $g.InterpolationMode = $mi }
                    # notificación de mensaje de "neems", como en el móvil
                    if ($script:popNoti) {
                        $n = $script:popNoti; $dy = if ($n.T -gt 74) { (80 - $n.T) * 8 - 48 } elseif ($n.T -lt 8) { - (8 - $n.T) * 6 } else { 0 }
                        $g.SetClip((New-Object System.Drawing.RectangleF(406, 58, [float]($W - 408), [float]($H - 60))))
                        $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), (Ruta-Redonda 423 (77 + $dy) 196 42 12))
                        $nr = Ruta-Redonda 420 (74 + $dy) 196 42 12
                        $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 240 250 246 255))), $nr); $g.DrawPath((New-Object System.Drawing.Pen((C 255 92 190), 1.5)), $nr); $nr.Dispose()
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 236 196 140))), 428, (81 + $dy), 28, 28)
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 120 80 50))), 430, (81 + $dy), 10, 14); $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 120 80 50))), 444, (81 + $dy), 10, 14)
                        $g.FillEllipse([System.Drawing.Brushes]::Black, 438, (95 + $dy), 7, 5)
                        $g.DrawString('neems', (FntP('Trebuchet MS', 8.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 200 40 140))), 462, (77 + $dy))
                        $g.DrawString('ahora', (FntP('Trebuchet MS', 7)), (New-Object System.Drawing.SolidBrush((C 150 140 170))), 576, (78 + $dy))
                        $g.DrawString($n.Txt, (FntP('Trebuchet MS', 8.5)), (New-Object System.Drawing.SolidBrush((C 40 24 60))), 462, (93 + $dy))
                        $g.ResetClip()
                    }
                    if ($script:popFx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ($script:popFx * 6) 255 92 190))), 406, 58, ($W - 410), ($H - 62)) }
                    # abajo: mensajes, No molestar y la canción
                    $osc = (ARGB 230 24 10 46)
                    Yt-Pastilla $g 16 280 124 24 $osc "✉  $($script:popMsgs) $(if ($script:popMsgs -eq 1) { 'mensaje' } else { 'mensajes' })" (C 255 255 255) 8.5
                    if ($script:popDND) { Yt-Pastilla $g 146 280 146 24 (ARGB 235 40 120 150) '☾  No molestar: SÍ' (C 255 255 255) 8.5 }
                    else { Yt-Pastilla $g 146 280 146 24 $osc '☾  No molestar: NO' (C 255 214 120) 8.5 }
                    Yt-Pastilla $g 298 280 100 24 $osc $(if ($script:popMusica) { '♪ pop music' } else { '♪ silencio' }) (C 255 92 190) 8
                }
                'gran' {
                    $e = $script:gr
                    # marco verde del monitor, líneas de pantalla y la etiqueta de la cámara del laboratorio
                    $sl = New-Object System.Drawing.Pen((ARGB 26 0 0 0), 1); for ($y = 62; $y -lt 266; $y += 3) { $g.DrawLine($sl, 414, $y, 748, $y) }; $sl.Dispose()
                    if ($e -and $e.Fx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($e.Fx * 9)) $e.FxCol.R $e.FxCol.G $e.FxCol.B))), 414, 62, 334, 204) }
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 32 208 44), 2)), 413, 61, 336, 206)
                    $osd = FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold)
                    if ([int]([Environment]::TickCount / 600) % 2 -eq 0) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 230 40 60))), 420, 68, 8, 8) }
                    $g.DrawString('CAM 07 · CENTRAL TOWER', $osd, (New-Object System.Drawing.SolidBrush((C 200 255 205))), 431, 65)
                    $g.DrawString('ANTIHUMAN INC.', $osd, (New-Object System.Drawing.SolidBrush((C 32 208 44))), 654, 252)
                    # registro de sujetos de prueba
                    if ($e) {
                        $pc = if ($e.Sujetos -gt 0) { [int](100 * $e.Exitos / $e.Sujetos) } else { 0 }
                        Texto-Color $g "SUJETOS: $($e.Sujetos)" 'Bahnschrift' 14 18 284 (C 200 255 205) (C 0 0 0) 3
                        Texto-Color $g "FURRIES: $($e.Exitos)" 'Bahnschrift' 14 150 284 (C 32 208 44) (C 0 0 0) 3
                        Texto-Color $g "ÉXITO: $pc %" 'Bahnschrift' 14 284 284 $(if ($pc -ge 60 -or $e.Sujetos -eq 0) { (C 200 255 205) } else { (C 255 110 130) }) (C 0 0 0) 3
                    }
                }
                'boneyard' {
                    $dyb = $script:dy; $ahora = [Environment]::TickCount
                    # fuegos fatuos (Summon Wisps): dos llamitas que flotan a los lados de Dybbuk
                    if ($dyb -and $dyb.WispsHasta -gt $ahora) {
                        if (-not $script:dyWisp) { $script:dyWisp = Cargar-Img $k.Wisp }
                        $quedan = ($dyb.WispsHasta - $ahora) / [double]$DyTiempos.Wisps
                        $al = [Math]::Min(1.0, [Math]::Min((1 - $quedan) * 5, $quedan * 4))
                        foreach ($q in @(@(474, 0.0), @(668, 1.7))) {
                            $fy = 128 + [Math]::Sin($ahora / 280.0 + $q[1]) * 10
                            $gl = New-Object System.Drawing.Drawing2D.GraphicsPath; $gl.AddEllipse([float]($q[0] - 6), [float]($fy + 10), 62, 62)
                            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gl); $pg.CenterColor = [System.Drawing.Color]::FromArgb([int](110 * $al), 120, 200, 255); $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 120, 200, 255))
                            $g.FillPath($pg, $gl); $pg.Dispose(); $gl.Dispose()
                            Dy-Img $g $script:dyWisp $q[0] $fy 50 78 $al
                        }
                    }
                    # posesión: el panel se tiñe de morado fantasma (sin parpadeo en modo seguro)
                    if ($dyb -and $dyb.Estado -eq 'posee') {
                        $pulso = if ($script:aj.Epilepsia) { 0.5 } else { 0.5 + 0.5 * [Math]::Sin($ahora / 320.0) }
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](35 + 45 * $pulso), 110, 70, 190))), 404, 56, ($W - 404), ($H - 56))
                        if ($ahora -ge $dyb.Fin) {
                            $tw = Ancho-Texto '¡EL PANEL ESTÁ POSEÍDO!' 'EdmundMcMillen_INTLv4' 20
                            Texto-Contorno $g '¡EL PANEL ESTÁ POSEÍDO!' 'EdmundMcMillen_INTLv4' 20 (582 - $tw / 2) 150 (C 220 200 255) 4
                        }
                    }
                    # barra de vida de jefe (como la de Guillotina) con la lápida del Boneyard
                    $hx = 432; $hy = 62; $hw = 314
                    $placa = Ruta-Redonda ($hx - 4) ($hy - 3) ($hw + 8) 28 12
                    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 22, 23, 28))), $placa)
                    $g.DrawPath((New-Object System.Drawing.Pen((C 120 142 156), 2.5)), $placa); $placa.Dispose()
                    if (-not $script:dyLapida) { $script:dyLapida = Cargar-Img $k.Lapida }
                    if ($script:dyLapida) { $g.DrawImage($script:dyLapida, ($hx - 2), ($hy - 2), 22, 25) }
                    $bx = $hx + 28; $bw = $hw - 32
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 22 26))), $bx, ($hy + 3), $bw, 16)
                    $hp = if ($dyb) { $dyb.HP } else { 85 }; $mx = if ($dyb) { $dyb.Max } else { 85 }
                    $frac = [Math]::Max(0, $hp) / [double]$mx
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 200 35 45))), $bx, ($hy + 3), [int]($bw * $frac), 16)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))), $bx, ($hy + 3), [int]($bw * $frac), 5)
                    $est = if ($dyb) { $dyb.Estado } else { 'vivo' }
                    $etq = if ($est -eq 'muerto') { 'DYBBUK  BAJO TIERRA' } elseif ($est -eq 'posee') { "¡DYBBUK POSEYENDO!  $hp/$mx" } else { "DYBBUK  $hp/$mx" }
                    Texto-Contorno $g $etq 'EdmundMcMillen_INTLv4' 14 ($bx + 6) ($hy + 2) (C 255 250 235) 3
                    # abajo: el cementerio y el maná que lleva lamido
                    Texto-Contorno $g 'THE BONEYARD' 'EdmundMcMillen_INTLv4' 15 16 277 (C 150 172 186) 3
                    Texto-Contorno $g "MANÁ LAMIDO: $(if ($dyb) { $dyb.Mana } else { 0 })" 'EdmundMcMillen_INTLv4' 14 158 278 (C 232 234 226) 3
                }
                'corrupta' {
                    $el2 = $script:el; $ahora = [Environment]::TickCount
                    $rab = if ($el2) { $el2.Rabia } else { 0.0 }; $glt = $el2 -and $el2.Glitch
                    # MODO GLITCH: todo rojo con rayas (en modo seguro, sin parpadeo)
                    if ($glt) {
                        $pulso = if ($script:aj.Epilepsia) { 0.5 } else { 0.5 + 0.5 * [Math]::Sin($ahora / 120.0) }
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](60 + 50 * $pulso), 200, 0, 40))), 404, 56, ($W - 404), ($H - 56))
                        $ray = New-Object System.Drawing.Pen((ARGB 40 0 0 0), 1); for ($yy = 58; $yy -lt $H; $yy += 4) { $g.DrawLine($ray, 404, $yy, $W, $yy) }; $ray.Dispose()
                    }
                    # con rabia (o en modo glitch) Ellie se parte en rosa y cian
                    $a = $script:actores['E']
                    if ($a -and $a.Visible -and ($rab -ge 60 -or $glt)) {
                        $img = $a.Imgs['main']; $r = $a.Rect
                        $s = [Math]::Min($r[2] / $img.Width, $r[3] / $img.Height); $iw = $img.Width * $s; $ih = $img.Height * $s
                        $ix = $r[0] + ($r[2] - $iw) / 2 + $a.OX; $iy = $r[1] + $r[3] - $ih + $a.OY
                        if (-not $script:elRojo) { $script:elRojo = Imagen-Color $img (C 255 30 90) $ih; $script:elCian = Imagen-Color $img (C 60 230 255) $ih }
                        $sep = if ($glt) { if ($script:aj.Epilepsia) { 5 } else { 4 + $Rnd.Next(0, 7) } } else { 2 + ($rab - 60) / 10.0 }
                        $al = if ($glt) { 0.32 } else { 0.3 }
                        Dy-Img $g $script:elRojo ($ix - $sep) $iy $iw $ih $al
                        Dy-Img $g $script:elCian ($ix + $sep) $iy $iw $ih $al
                    }
                    # píxeles corruptos
                    if ($el2) { foreach ($bq in $el2.Bloques) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int][Math]::Min(230, $bq.T * 18), $bq.C.R, $bq.C.G, $bq.C.B))), [float]$bq.X, [float]$bq.Y, [float]$bq.W, [float]$bq.H) } }
                    if ($glt) {
                        $tx = Ancho-Texto 'MODO GLITCH 100%' 'Arial Black' 20; $jit = if ($script:aj.Epilepsia) { 0 } else { $Rnd.Next(-3, 4) }
                        Texto-Contorno $g 'MODO GLITCH 100%' 'Arial Black' 20 (590 - $tx / 2 + $jit) 62 (C 255 60 100) 4
                    }
                    # abajo a la izquierda: la barra GLITCH (su rabia)
                    Texto-Contorno $g 'GLITCH' 'Arial Black' 13 16 278 (C 255 92 170) 3
                    $bx = 92; $by = 281; $bw = 200
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 10 30))), $bx, $by, $bw, 13)
                    $colB = if ($glt) { (C 255 40 80) } elseif ($rab -ge 60) { (C 255 92 170) } else { (C 90 230 255) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colB)), $bx, $by, [int]($bw * $rab / 100.0), 13)
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 255 92 170), 1.5)), $bx, $by, $bw, 13)
                    $txt = if ($glt) { '100% !!' } else { "$([int]$rab)%" }
                    Texto-Contorno $g $txt 'Arial Black' 11 ($bx + $bw + 8) 279 (C 255 236 244) 3
                    Texto-Contorno $g "NATILLAS: $(if ($el2) { $el2.Natillas } else { 0 })" 'Arial Black' 10 300 300 (C 255 214 90) 3
                }
                'evil' {
                    $e = $script:es; $ahora = [Environment]::TickCount
                    $cerca = if ($e) { 1.0 - $e.Vis / 100.0 } else { 0.0 }
                    # cuanto más cerca, más rojo se pone todo (en modo seguro sin parpadeo)
                    $pulso = if ($script:aj.Epilepsia) { 0.5 } else { 0.5 + 0.5 * [Math]::Sin($ahora / 260.0) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](70 * $cerca * $cerca * (0.6 + 0.4 * $pulso)), 160, 0, 10))), 404, 56, ($W - 404), ($H - 56))
                    # aviso de la alarma y de la carga
                    if ($e -and $e.Fase -eq 'aviso') {
                        $on = $script:aj.Epilepsia -or ([int]($ahora / 300) % 2 -eq 0)
                        if ($on) { $tw = Ancho-Texto '⚠ STALL ⚠' 'Arial Black' 26; Texto-Color $g '⚠ STALL ⚠' 'Arial Black' 26 (580 - $tw / 2) 64 (C 255 210 40) (C 0 0 0) 6 }
                        Texto-Color $g '¡HAZ CLIC EN ÉL PARA BLOQUEARLO!' 'Arial' 11 470 102 (C 255 255 255) (C 0 0 0) 4
                    } elseif ($e -and $e.Fase -eq 'carga') {
                        Texto-Color $g '¡¡CARGA!!' 'Arial Black' 24 516 64 (C 230 30 40) (C 0 0 0) 6
                    }
                    # el susto: la cara roja ocupa toda la pantalla (en modo seguro, Sin-Destellos lo apaga)
                    if ($e -and $e.Fx -gt 0) {
                        if (-not $script:esSusto) { $script:esSusto = Cargar-Img $k.Susto }
                        $al = [Math]::Min(1.0, $e.Fx / 10.0)
                        if ($script:esSusto) {
                            $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$al
                            $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                            $z = 1.0 + (1 - $al) * 0.3; $sw = $W * $z; $sh = $sw * $script:esSusto.Height / $script:esSusto.Width; if ($sh -lt $H * $z) { $sh = $H * $z; $sw = $sh * $script:esSusto.Width / $script:esSusto.Height }
                            $g.DrawImage($script:esSusto, (New-Object System.Drawing.Rectangle([int]($W / 2 - $sw / 2 + $Rnd.Next(-6, 7)), [int]($H / 2 - $sh / 2 + $Rnd.Next(-4, 5)), [int]$sw, [int]$sh)), 0, 0, $script:esSusto.Width, $script:esSusto.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                            $ia.Dispose()
                        }
                    }
                    # abajo: distancia, rebotes, sustos y bloqueos
                    $osc = (ARGB 235 22 10 12); $cl = (C 236 220 220)
                    Yt-Pastilla $g 16 280 170 24 $osc $null $null 8
                    $g.DrawString('DISTANCIA', (FntP('Arial', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 26, 285)
                    $dv = if ($e) { $e.Vis } else { 100 }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 16 18))), 92, 287, 86, 10)
                    $colD = if ($dv -lt 30) { (C 230 30 40) } elseif ($dv -lt 60) { (C 230 140 40) } else { (C 120 200 120) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colD)), 92, 287, [float](86 * $dv / 100.0), 10)
                    $fase = if (-not $e) { '' } elseif ($e.Fase -eq 'aviso') { '⚠ STALL' } elseif ($e.Fase -eq 'carga') { '¡CARGA!' } else { $cada = $(if ($e.Gigante) { 4 } else { 6 }); "rebote $($e.Rebotes % $cada)/$cada" }
                    Yt-Pastilla $g 190 280 88 24 $osc $fase $cl 8
                    Yt-Pastilla $g 282 280 116 24 $osc "😱 $(if ($e) { $e.Sustos } else { 0 })   🛡 $(if ($e) { $e.Bloqueos } else { 0 })" $cl 8.5
                    if ($e -and $e.Gigante) { Texto-Color $g 'GIGANTE' 'Arial Black' 11 690 64 (C 255 210 40) (C 0 0 0) 4 }
                }
                'knight' {
                    $e = $script:kn
                    # el rugido: luz roja que sale del Knight (en modo seguro Sin-Destellos lo apaga)
                    if ($e -and $e.Fx -gt 0) {
                        $q = [Math]::Min(1.0, $e.Fx / 20.0)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](110 * $q), 200, 0, 20))), 404, 56, ($W - 404), ($H - 56))
                        $pr = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int](200 * $q), 255, 60, 60), 3)
                        for ($i = 0; $i -lt 10; $i++) { $a = $i * [Math]::PI / 5 + $e.Fx / 10.0; $g.DrawLine($pr, 648, 140, [float](648 + [Math]::Cos($a) * 260), [float](140 + [Math]::Sin($a) * 260)) }
                        $pr.Dispose()
                    }
                    # botón FIGHT
                    $r = Kn-Fight-Rect; $sobre = Kn-Fight-En-Raton
                    $colF = if ($sobre) { (C 255 255 0) } else { (C 255 160 64) }
                    $g.FillRectangle([System.Drawing.Brushes]::Black, $r[0], $r[1], $r[2], $r[3])
                    $g.DrawRectangle((New-Object System.Drawing.Pen($colF, 2)), $r[0], $r[1], $r[2], $r[3])
                    if ($sobre) { Kn-Corazon $g ($r[0] + 13) ($r[1] + 13) 6 ([System.Drawing.Color]::Red) }
                    else { $g.DrawString('⚔', (FntP('Segoe UI Symbol', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($colF)), ($r[0] + 4), ($r[1] + 2)) }
                    $g.DrawString('FIGHT', (FntP('Consolas', 13, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($colF)), ($r[0] + 28), ($r[1] + 3))
                    # abajo: Fuentes, barra ROARING, Titanes y victorias en el minijuego
                    Kn-Caja $g 16 280 382 24
                    $fb = FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold); $bl = [System.Drawing.Brushes]::White
                    $g.DrawString("FUENTES $(if ($e) { $e.Fuentes } else { 0 })", $fb, $bl, 22, 286)
                    $g.DrawString('ROARING', $fb, (New-Object System.Drawing.SolidBrush((C 255 80 80))), 110, 286)
                    $rv = if ($e) { $e.Roaring } else { 0 }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 0 0))), 162, 288, 80, 9)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 220 30 30))), 162, 288, [float](80 * $rv / 100.0), 9)
                    $g.DrawString("TITANES $(if ($e) { $e.Titanes } else { 0 })", $fb, $bl, 250, 286)
                    $g.DrawString("WIN $($script:aj.KnightVictorias)", $fb, (New-Object System.Drawing.SolidBrush((C 255 255 0))), 336, 286)
                }
                'niebla' {
                    $e = $script:sf
                    # niebla de siempre, suave, por la escena
                    Pintar-Niebla $g 404 $W $H 0.35
                    # niebla espesa (cada 6 apps y al salir de la intro, que se va despejando)
                    $q = Sf-Espesor
                    if ($q -gt 0) {
                        Pintar-Niebla $g 0 $W $H $q
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]($e.NieblaTope * $q), 255, 186, 244))), 0, 0, $W, $H)
                    }
                    # abajo: la barra de EXISTENCIA, manos que le han atravesado y sustos/corazones de Orange Cat
                    $osc = (ARGB 225 50 20 86); $cl = (C 255 225 250)
                    Yt-Pastilla $g 16 280 196 24 $osc $null $null 8
                    $g.DrawString('EXISTENCIA', (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 24, 285)
                    $ev = if ($e) { $e.Vis } else { 70 }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 30 10 50))), 100, 287, 104, 10)
                    $colE = if ($ev -lt 20) { (C 150 120 160) } elseif ($ev -lt 50) { (C 230 140 220) } else { (C 255 120 240) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colE)), 100, 287, [float](104 * $ev / 100.0), 10)
                    Yt-Pastilla $g 218 280 86 24 $osc "manos: $(if ($e) { $e.Manos } else { 0 })" $cl 8.5
                    Yt-Pastilla $g 310 280 88 24 $osc "♥ cat: $(if ($e) { $e.Gato } else { 0 })" $cl 8.5
                }
                'abismo' {
                    $e = $script:nn
                    # los hilos del campo de fuerza (más fuertes cuando está feliz)
                    Dibujar-Campo $g 410 58 346 212 $(if ($e -and $e.Fx -gt 0) { 110 } else { 45 })
                    # su dibujo en la pared: papel con celo y su cara del anime dentro
                    $dx = 416; $dy = 66; $dw = 156; $dh = 98
                    $st = $g.Save(); $g.TranslateTransform([float]($dx + $dw / 2), [float]($dy + $dh / 2)); $g.RotateTransform(-3)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), [float](-$dw / 2 + 4), [float](-$dh / 2 + 4), [float]($dw + 8), [float]($dh + 22))
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 246 236 212))), [float](-$dw / 2 - 4), [float](-$dh / 2 - 4), [float]($dw + 8), [float]($dh + 22))
                    $cara = if ($e -and $e.Cara -and [Environment]::TickCount -lt $e.CaraHasta) { $e.Cara } else { 'chulo' }
                    $c = Nn-Gif $cara
                    if ($c) { Gif-Frame $c.Img $c.Info ([Environment]::TickCount); $g.DrawImage($c.Img, [float](-$dw / 2), [float](-$dh / 2), [float]$dw, [float]$dh) }
                    $g.DrawString('Nanachi ♪', (FntP('Segoe Print', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 120 80 60))), [float](-$dw / 2), [float]($dh / 2))
                    $celo = New-Object System.Drawing.SolidBrush((ARGB 150 255 240 170))
                    $g.FillRectangle($celo, [float](-$dw / 2 - 12), [float](-$dh / 2 - 8), 30, 10); $g.FillRectangle($celo, [float]($dw / 2 - 18), [float](-$dh / 2 - 8), 30, 10); $celo.Dispose()
                    $g.Restore($st)
                    # el muñeco de pájaro que Nanachi cosió para Mitty, delante de ella
                    Dibujar-Muneco $g 520 240
                    # la olla del estofado, con vapor y burbujas
                    if (-not $script:nnOlla) { $script:nnOlla = Cargar-Img $k.Estofado }
                    if ($script:nnOlla) { $g.DrawImage($script:nnOlla, 430, 204, 92, 69) }
                    $t = [Environment]::TickCount / 1000.0; $va = if ($e -and $e.Vapor -gt 0) { 150 } else { 70 }
                    for ($i = 0; $i -lt 3; $i++) {
                        $vx = 458 + $i * 16; $vp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($va, 240, 240, 240), 3); $vp.StartCap = 'Round'; $vp.EndCap = 'Round'
                        $g.DrawBezier($vp, [float]$vx, 206, [float]($vx + 8 * [Math]::Sin($t * 2 + $i)), 194, [float]($vx - 8 * [Math]::Sin($t * 2 + $i)), 182, [float]$vx, 170); $vp.Dispose()
                    }
                    # ingredientes ya echados (puntitos) encima de la olla
                    if ($e) { for ($i = 0; $i -lt 5; $i++) { $g.FillEllipse((New-Object System.Drawing.SolidBrush($(if ($i -lt $e.Ing) { (C 236 170 190) } else { (ARGB 120 60 44 34) }))), [float](446 + $i * 13), 196, 9, 9) } }
                    # abajo: estofados servidos, medidor de MULLIDO y la profundidad
                    $osc = (ARGB 230 64 46 32); $cl = (C 252 240 214)
                    $ne = if ($e) { $e.Estofados } else { 0 }
                    Yt-Pastilla $g 16 280 110 24 $osc "🍲  $ne $(if ($ne -eq 1) { 'estofado' } else { 'estofados' })" $cl 8.5
                    Yt-Pastilla $g 132 280 152 24 $osc $null $null 8
                    $g.DrawString('MULLIDO', (FntP('Trebuchet MS', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 140, 285)
                    $mv = if ($e) { $e.Mullido } else { 0 }
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 40 28 20))), (Ruta-Redonda 196 287 80 10 5))
                    if ($mv -gt 1) { $g.FillPath((New-Object System.Drawing.SolidBrush((C 236 170 190))), (Ruta-Redonda 196 287 ([Math]::Max(10.0, 80.0 * $mv / 100.0)) 10 5)) }
                    Yt-Pastilla $g 290 280 108 24 $osc '⬇ 4ª capa · 7.100 m' $cl 7.5
                }
                'lobo' { Ag-Pintar $g $W $H $k }
                'arana' { Vv-Pintar $g $W $H $k }
                'clima' { Wg-Pintar $g $W $H $k }
                'pintor' { Pr-Pintar $g $W $H $k }
                'historia' {
                    $e = $script:mk
                    # la mesa con los libros que van llegando y la vela-patata
                    Mk-Pintar-Mesa $g $e
                    # al subir el nivel de emoción, un brillo dorado suave sobre la escena
                    if ($e -and $e.Fx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int][Math]::Min(100, $e.Fx * 8)) 255 210 110))), 404, 56, ($W - 404), 218) }
                    # el ejercicio de respiración: un círculo dorado que crece (coger aire) y se encoge (soltarlo)
                    if ($e -and $e.Respira -gt 0) {
                        $q = [Math]::Min(1.0, ([Environment]::TickCount - $e.RespiraT0) / [double]$MkTiempos.Respira)
                        $rad = 18 + 46 * [Math]::Sin($q * [Math]::PI); $cx = 508; $cy = 136
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 50 255 220 140))), [float]($cx - $rad), [float]($cy - $rad), [float](2 * $rad), [float](2 * $rad))
                        $g.DrawEllipse((New-Object System.Drawing.Pen((ARGB 200 255 220 140), 2.5)), [float]($cx - $rad), [float]($cy - $rad), [float](2 * $rad), [float](2 * $rad))
                        $g.DrawEllipse((New-Object System.Drawing.Pen((ARGB 90 255 220 140), 1)), [float]($cx - 64), [float]($cy - 64), 128, 128)
                        $txr = if ($q -lt 0.5) { 'COGE AIRE' } else { 'SUÉLTALO' }
                        $fr = FntP('Palatino Linotype', 10, [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($txr, $fr).Width
                        Texto-Color $g $txr 'Palatino Linotype' 13 ($cx - $tw / 2 - 2) ($cy - 9) (C 250 242 222) (C 60 40 20) 3
                    }
                    # Realización de la Planta: la carta "The Will to Stand up Straight"
                    if ($e -and $e.EgoT -gt 0) {
                        if (-not $script:mkEgo) { $script:mkEgo = Cargar-Img $k.Ego }
                        $q = 90 - $e.EgoT; $esc = [Math]::Min(1.0, $q / 6.0); $alf = [Math]::Min(1.0, $e.EgoT / 10.0)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](150 * $alf)) 10 6 2))), 404, 56, ($W - 404), 218)
                        if ($script:mkEgo) {
                            $cw = 196 * (0.6 + 0.4 * $esc); $ch = $cw * $script:mkEgo.Height / $script:mkEgo.Width; $cx = 512 - $cw / 2; $cy = 132 - $ch / 2
                            $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$alf
                            $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                            $g.DrawImage($script:mkEgo, (New-Object System.Drawing.Rectangle([int]$cx, [int]$cy, [int]$cw, [int]$ch)), 0, 0, $script:mkEgo.Width, $script:mkEgo.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia); $ia.Dispose()
                            $g.DrawRectangle((New-Object System.Drawing.Pen((ARGB ([int](255 * $alf)) 236 196 106), 2)), [float]$cx, [float]$cy, [float]$cw, [float]$ch)
                            Texto-Color $g 'THE WILL TO STAND UP STRAIGHT' 'Palatino Linotype' 11 418 ([float]($cy + $ch + 6)) (ARGB ([int](255 * $alf)) 250 232 180) (ARGB ([int](255 * $alf)) 30 20 10) 3
                            $g.DrawString('Realización de la Planta de Historia', (FntP('Palatino Linotype', 8, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $alf)) 236 196 106))), 420, [float]($cy + $ch + 24))
                        }
                    }
                    # abajo: libros catalogados, NIVEL DE EMOCIÓN (5 puntos, como en el juego) y ÁNIMO
                    $osc = (ARGB 230 60 40 18); $cl = (C 250 236 200)
                    $nl = if ($e) { $e.Libros } else { 0 }
                    Yt-Pastilla $g 16 280 98 24 $osc "📖 $nl $(if ($nl -eq 1) { 'libro' } else { 'libros' })" $cl 8.5
                    Yt-Pastilla $g 120 280 150 24 $osc $null $null 8
                    $g.DrawString('EMOCIÓN', (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 128, 285)
                    $nv = if ($e) { $e.Nivel } else { 0 }
                    for ($i = 0; $i -lt 5; $i++) {
                        $pc = if ($i -lt $nv) { (C 255 210 100) } else { (C 40 28 14) }
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush($pc)), [float](188 + $i * 15), 286, 11, 11)
                        $g.DrawEllipse((New-Object System.Drawing.Pen((C 214 170 90), 1)), [float](188 + $i * 15), 286, 11, 11)
                    }
                    Yt-Pastilla $g 276 280 122 24 $osc $null $null 8
                    $g.DrawString('ÁNIMO', (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 284, 285)
                    $av = if ($e) { $e.Animo } else { 80 }
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 40 28 14))), (Ruta-Redonda 322 287 68 10 5))
                    $ca = if ($e -and $e.Hundida) { (C 120 130 150) } elseif ($av -lt 50) { (C 230 150 60) } else { (C 150 210 110) }
                    if ($av -gt 1) { $g.FillPath((New-Object System.Drawing.SolidBrush($ca)), (Ruta-Redonda 322 287 ([Math]::Max(10.0, 68.0 * $av / 100.0)) 10 5)) }
                }
                'enfosi' {
                    $e = $script:ef
                    if ($e) {
                        # vida de la estatua
                        $fr = [Math]::Max(0.0, $e.HP / [double]$e.HPMax)
                        $cv = if ($fr -gt 0.5) { (C 90 200 60) } elseif ($fr -gt 0.25) { (C 240 180 30) } else { (C 230 40 40) }
                        Texto-Color $g 'ESTATUA' 'Arial Black' 9 410 60 (C 255 255 255) (C 20 20 20) 3
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 0 0 0))), 408, 76, 118, 12)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($cv)), 410, 78, [int](114 * $fr), 8)
                        $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1)), 408, 76, 118, 12)
                        # strikes: tres caritas (una X roja por cada strike)
                        for ($i = 0; $i -lt 3; $i++) { Dibujar-Carita $g (704 + $i * 22) 74 9 ($i -ge $e.Strikes) }
                        # vida de los Enphosians descubiertos y de los jefes
                        if ($e.W -and $e.W.Estado -in @('revelado', 'ataca')) {
                            $aw = $script:actores['W']
                            for ($i = 0; $i -lt $e.W.Vida; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 40 40))), [float]($e.W.X + 4 + $i * 9), [float]($aw.Rect[1] - 4), 7, 7); $g.DrawRectangle((New-Object System.Drawing.Pen((C 20 20 20), 1)), [float]($e.W.X + 4 + $i * 9), [float]($aw.Rect[1] - 4), 7, 7) }
                        }
                        # explosión negra al descubrir un Enphosian
                        if ($e.Negro -gt 0) {
                            $q = 16 - $e.Negro
                            for ($k2 = 0; $k2 -lt 3; $k2++) { $rr = 10 + $q * 6 + $k2 * 10; $g.DrawEllipse((New-Object System.Drawing.Pen((ARGB ([int][Math]::Max(0, 230 - $q * 14)) 0 0 0), 8)), [float]($e.NX - $rr), [float]($e.NY - $rr), [float](2 * $rr), [float](2 * $rr)) }
                        }
                        # el Ojo de Enphoso se acerca
                        if ($e.Ojo -gt 0) {
                            $q = $e.Ojo; $sz = 40 + $q * 1.15; $al = [float]([Math]::Min(1.0, $q / 20.0) * 0.95)
                            $ox = 720 - $q * 0.75; $oy = 150
                            $oj = Enfosi-Img 'ojo.png'
                            if ($oj) {
                                $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = $al
                                $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                                $g.DrawImage($oj, (New-Object System.Drawing.Rectangle([int]($ox - $sz / 2), [int]($oy - $sz / 2), [int]$sz, [int]$sz)), 0, 0, $oj.Width, $oj.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia); $ia.Dispose()
                            }
                            $tt = Enfosi-Img 'enphoso_titulo.png'
                            if ($tt -and (([Environment]::TickCount / 350) % 2) -lt 1) { $g.DrawImage($tt, 560, 92, 150, [float]($tt.Height * 150 / $tt.Width)) }
                        }
                        # flash rojo de strike
                        if ($e.Rojo -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int][Math]::Min(200, $e.Rojo * 14)) 220 20 20))), 400, 56, ($W - 400), 218) }
                        # cartel de oleada
                        if ($e.Banner) {
                            $bi = Enfosi-Img $e.Banner.Img
                            if ($bi) { $q = 55 - $e.Banner.T; $es = if ($q -lt 4) { $q / 4.0 * 1.1 } elseif ($q -lt 7) { 1.1 - ($q - 4) / 30.0 } else { 1.0 }; $bw = 300 * [Math]::Max(0.05, $es); $bh = $bi.Height * $bw / $bi.Width; $g.DrawImage($bi, [float](585 - $bw / 2), [float](150 - $bh / 2), [float]$bw, [float]$bh) }
                        }
                        # rango al acabar la oleada, o la pantalla de GAME OVER
                        if ($e.Cartel) {
                            $ci = Enfosi-Img $e.Cartel.Img
                            if ($ci) {
                                if ($e.Cartel.Img -eq 'gameover.jpg') {
                                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), 400, 56, ($W - 400), 218)
                                    $ch = 210; $cw = $ci.Width * $ch / $ci.Height; $g.DrawImage($ci, [float](585 - $cw / 2), 60, [float]$cw, [float]$ch)
                                } else {
                                    $q = $e.Cartel.Max - $e.Cartel.T; $es = [Math]::Max(0.05, [Math]::Min(1.0, $q / 5.0))
                                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 400, 56, ($W - 400), 218)
                                    $cw = 260 * $es; $ch = $ci.Height * $cw / $ci.Width; $g.DrawImage($ci, [float](585 - $cw / 2), [float](160 - $ch / 2), [float]$cw, [float]$ch)
                                }
                            }
                        }
                        # marcador: oleada, puntos, Bintar
                        Texto-Color $g "OLEADA $($e.Ola)/7" 'Arial Black' 14 16 284 (C 255 255 255) (C 20 20 20) 4
                        Texto-Color $g "PUNTOS $($e.Puntos)" 'Arial Black' 12 140 286 (C 255 214 60) (C 20 20 20) 4
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 250 200 40))), 268, 286, 16, 16); $g.DrawEllipse((New-Object System.Drawing.Pen((C 120 80 0), 1.5)), 268, 286, 16, 16)
                        $g.DrawString('B', (FntP('Arial Black', 7)), (New-Object System.Drawing.SolidBrush((C 120 80 0))), 271, 287)
                        Texto-Color $g "x$($e.Bintar)" 'Arial Black' 12 288 286 (C 255 255 255) (C 20 20 20) 4
                        if ($e.Sobber) { Texto-Color $g 'SOBBER' 'Arial Black' 12 336 286 (C 110 150 255) (C 20 20 20) 4 }
                    }
                }
                'teto' {
                    # pajaritos posados o volando
                    foreach ($p in $script:pajaros) { Dibujar-Pajaro $g $p.X $p.Y 1.0 ($p.Est -in @('vuela', 'huye')) $p.F $p.Dir }
                    # contador de pajaritos (cinco = ¡birdbrain!)
                    Texto-Contorno $g 'PAJARITOS' 'Arial Black' 13 18 302 (C 255 255 255) 4
                    $vivos = @($script:pajaros | Where-Object { $_.Est -in @('posado', 'cabeza') }).Count
                    for ($i = 0; $i -lt 5; $i++) {
                        if ($i -lt $vivos) { Dibujar-Pajaro $g (124 + $i * 28) 318 0.8 $false 0 1 }
                        else { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 176 24 48))), (116 + $i * 28), 306, 14, 9) }
                    }
                    if ($script:birdbrains -gt 0) { Texto-Contorno $g "BIRDBRAIN x$($script:birdbrains)" 'Arial Black' 12 268 303 (C 246 204 60) 4 }
                }
                'pressure' {
                    # mostrador de la tienda, delante de Sebastian
                    $mx = 426; $my = 222; $mw = $W - $mx
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 92 102 112))), $mx, $my, $mw, 6)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 150 162 172))), $mx, $my, $mw, 2)
                    $fr = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle($mx, ($my + 6), $mw, 40)), (C 40 46 54), (C 16 20 26), 90)
                    $g.FillRectangle($fr, $mx, ($my + 6), $mw, 40); $fr.Dispose()
                    foreach ($rx in @(($mx + 8), ($mx + $mw / 2), ($W - 12))) { foreach ($ry in @(($my + 12), ($my + 30))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 110 120 130))), [float]$rx, [float]$ry, 4, 4) } }
                    # objetos a la venta encima del mostrador
                    Dibujar-Objeto $g 'linterna' 436 ($my - 22) 24
                    Dibujar-Objeto $g 'pilas' 462 ($my - 18) 20
                    Dibujar-Objeto $g 'botiquin' 704 ($my - 24) 26
                    Dibujar-Objeto $g 'splorg' 732 ($my - 20) 22
                    # cartel: se enciende cuando la tienda está abierta
                    $on = $script:modoTienda -or ([Math]::Floor([Environment]::TickCount / 900) % 2 -eq 0)
                    $cl = if ($script:modoTienda) { (C 255 190 70) } elseif ($on) { (C 120 200 210) } else { (C 60 90 96) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 8 10 14))), 520, ($my + 10), 160, 22)
                    $g.DrawRectangle((New-Object System.Drawing.Pen($cl, 1)), 520, ($my + 10), 160, 22)
                    $cartel = if ($script:modoTienda) { "SEBASTIAN'S SHOP · OPEN" } else { "SEBASTIAN'S SHOP" }
                    $tw = Ancho-Texto $cartel 'Bahnschrift' 12
                    Texto-Contorno $g $cartel 'Bahnschrift' 12 (600 - $tw / 2) ($my + 13) $cl 2
                    # destello del Flash Beacon y enfado (GET. OUT!)
                    if ($script:destello -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $script:destello * 22), 255, 255, 240))), 400, 56, ($W - 400), ($H - 56)) }
                    if ($script:enfadoFx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]([Math]::Min(1.0, $script:enfadoFx / 10.0) * 120), 200, 0, 0))), 0, 0, $W, $H) }
                    # investigación y los últimos objetos comprados
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 230 240))), 18, 279, 7, 14); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 220 240 245))), 16, 277, 11, 3)
                    Texto-Contorno $g "INVESTIGACIÓN  $($script:investigacion)" 'Bahnschrift' 14 32 276 (C 220 240 245) 3
                    for ($i = 0; $i -lt 5; $i++) {
                        $sx = 222 + $i * 34
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 10 14 18))), $sx, 272, 30, 30)
                        $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 190 200), 1)), $sx, 272, 30, 30)
                        if ($i -lt $script:inventario.Count) { Dibujar-Objeto $g $script:inventario[$i] ($sx + 2) 274 26 }
                    }
                }
                'dod' {
                    # Pursuer invisible: solo se ven sus ojos verdes
                    if ($script:acechando) {
                        $al = [int](40 + [Math]::Sin([Environment]::TickCount / 300.0) * 30)
                        foreach ($ex in @(590, 618)) { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 60, 255, 190))), $ex, 92, 14, 9) }
                    }
                    # aullido: ondas que se expanden
                    foreach ($o in $script:ondas) {
                        $al = [Math]::Max(0, [Math]::Min(255, $o.T * 8))
                        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 120, 255, 200), 4)
                        $g.DrawEllipse($pen, [float](605 - $o.R), [float](130 - $o.R * 0.6), [float](2 * $o.R), [float](1.2 * $o.R)); $pen.Dispose()
                    }
                    # zarpazos
                    foreach ($z in $script:zarpas) {
                        $al = [Math]::Max(0, [Math]::Min(255, $z.T * 10))
                        $st = $g.Save(); $g.TranslateTransform([float]$z.X, [float]$z.Y); $g.RotateTransform([float]$z.A)
                        foreach ($dx in @(-14, 0, 14)) {
                            $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 120, 0, 0), 7)), [float]$dx, -40, [float]($dx + 10), 40)
                            $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 255, 70, 60), 3)), [float]$dx, -40, [float]($dx + 10), 40)
                        }
                        $g.Restore($st)
                    }
                    foreach ($o in $script:gotas) { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $o.T * 10), 190, 10, 20))), [float]$o.X, [float]$o.Y, 6, 8) }
                    if ($script:rojoFx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($script:rojoFx * 14, 200, 0, 0))), 0, 0, $W, $H) }
                    # presas y estamina
                    Texto-Contorno $g "PRESAS: $($script:presas)" 'Arial Black' 14 16 276 (C 255 80 70) 3
                    Texto-Contorno $g 'ESTAMINA' 'Arial Black' 11 140 279 (C 120 255 200) 3
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 10 30 22))), 222, 281, 160, 11)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 220 150))), 222, 281, [int](160 * $script:estamina / 110), 11)
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 130 91), 1.5)), 222, 281, 160, 11)
                }
                'mew' {
                    # fase 2: el callejón late en rojo
                    if ($script:gFase2 -and $script:gVivo) {
                        $al = [int](45 + [Math]::Sin($script:fase * 2) * 30)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 200, 20, 20))), 400, 56, ($W - 400), ($H - 56))
                    }
                    # barra de vida de jefa con calavera
                    $hx = 432; $hy = 62; $hw = 314
                    $placa = Ruta-Redonda ($hx - 4) ($hy - 3) ($hw + 8) 28 12
                    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 24, 18, 20))), $placa)
                    $g.DrawPath((New-Object System.Drawing.Pen((C 120 40 35), 2.5)), $placa); $placa.Dispose()
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 240 228 200))), ($hx), ($hy), 22, 22)
                    $g.FillEllipse([System.Drawing.Brushes]::Black, ($hx + 5), ($hy + 7), 5, 6); $g.FillEllipse([System.Drawing.Brushes]::Black, ($hx + 12), ($hy + 7), 5, 6)
                    $g.FillRectangle([System.Drawing.Brushes]::Black, ($hx + 8), ($hy + 16), 6, 2)
                    $bx = $hx + 28; $bw = $hw - 32
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 22 22))), $bx, ($hy + 3), $bw, 16)
                    $frac = if ($script:gMax -gt 0) { [Math]::Max(0, $script:gHP) / $script:gMax } else { 0 }
                    $colVida = if ($script:gFase2) { (C 240 90 30) } else { (C 200 35 35) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colVida)), $bx, ($hy + 3), [int]($bw * $frac), 16)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))), $bx, ($hy + 3), [int]($bw * $frac), 5)
                    $etq = if (-not $script:gVivo) { 'GUILLOTINA  DERROTADA' } elseif ($script:gFase2) { "¡GUILLOTINA FURIOSA!  $($script:gHP)/$($script:gMax)" } else { "GUILLOTINA  $($script:gHP)/$($script:gMax)" }
                    Texto-Contorno $g $etq 'EdmundMcMillen_INTLv4' 14 ($bx + 6) ($hy + 2) (C 255 250 235) 3
                    # radio y gatos engullidos
                    Texto-Contorno $g 'WMEW 99.9' 'EdmundMcMillen_INTLv4' 15 16 277 (C 215 75 60) 3
                    Texto-Contorno $g "GATOS ENGULLIDOS: $($script:gComidos)" 'EdmundMcMillen_INTLv4' 14 128 278 (C 240 228 200) 3
                }
                'oeste' {
                    # agujeros de bala que se van borrando
                    foreach ($ag in $script:agujeros2) {
                        $al = [int][Math]::Min(255, $ag.T * 3)
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]($al * 0.6), 120, 90, 60))), [float]($ag.X - 10), [float]($ag.Y - 10), 20, 20)
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 10, 6, 4))), [float]($ag.X - 5), [float]($ag.Y - 5), 10, 10)
                        $gr = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 40, 24, 12), 1.5)
                        foreach ($an in @(20, 110, 200, 290)) { $ra = $an * [Math]::PI / 180; $g.DrawLine($gr, [float]$ag.X, [float]$ag.Y, [float]($ag.X + [Math]::Cos($ra) * 13), [float]($ag.Y + [Math]::Sin($ra) * 13)) }
                        $gr.Dispose()
                    }
                    # buitres en círculos y polvo que se lleva el viento
                    $tz = [Environment]::TickCount / 1000.0
                    Dibujar-Buitre $g (478 + [Math]::Cos($tz * 0.55) * 46) (84 + [Math]::Sin($tz * 0.55) * 10) 1.0 ($tz * 4)
                    Dibujar-Buitre $g (452 + [Math]::Cos($tz * 0.4 + 2) * 30) (130 + [Math]::Sin($tz * 0.4 + 2) * 7) 0.7 ($tz * 4 + 1)
                    for ($i = 0; $i -lt 9; $i++) {
                        $px = 410 + (($tz * (30 + $i * 4) + $i * 53) % 350); $py = 196 + (($i * 17) % 56) + [Math]::Sin($tz * 2 + $i) * 4
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 100 255 222 170))), [float]$px, [float]$py, 2.4, 2.4)
                    }
                    # planta rodadora
                    if ($script:tumbX -gt 360) { Dibujar-Rodadora $g $script:tumbX (234 - [Math]::Abs([Math]::Sin($script:tumbX / 28.0)) * 14) 15 ($script:tumbX * 4) }
                    # duelo: franjas de cine, "¿PREPARADO?" y "DRAW!"
                    if ($script:duelo) {
                        $d = $script:duelo
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 230 8 4 6))), 400, 56, ($W - 400), 26)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 230 8 4 6))), 400, 232, ($W - 400), 26)
                        if ($d.Fase -eq 'espera') {
                            if ((([Environment]::TickCount / 400) % 2) -lt 1) { Texto-Color $g '¿PREPARADO?' 'EdmundMcMillen_INTLv4' 20 520 58 (C 255 214 120) (C 60 20 10) 4 }
                            Texto-Color $g 'NO HAGAS CLIC TODAVÍA' 'EdmundMcMillen_INTLv4' 13 506 236 (C 250 236 205) (C 0 0 0) 3
                        } elseif ($d.Fase -eq 'draw') {
                            $st = $g.Save(); $g.TranslateTransform(560, 150); $g.RotateTransform(-8); $e = 1.4 - [Math]::Min(0.4, $d.T * 0.1); $g.ScaleTransform([float]$e, [float]$e)
                            Texto-Color $g 'DRAW!' 'EdmundMcMillen_INTLv4' 64 (-110) (-44) (C 235 46 34) (C 255 220 90) 10
                            $g.Restore($st)
                            Texto-Color $g '¡HAZ CLIC EN ZODIAC!' 'EdmundMcMillen_INTLv4' 13 512 236 (C 255 214 120) (C 0 0 0) 3
                        }
                    }
                    # fogonazo del disparo
                    if ($script:fogonazo -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($script:fogonazo * 30, 255, 240, 180))), 400, 56, ($W - 400), ($H - 56)) }
                    # tambor del revólver con las 6 balas
                    $cx = 722; $cy = 94; $rr = 26
                    $st = $g.Save(); $g.TranslateTransform([float]$cx, [float]$cy); $g.RotateTransform([float]$script:rotTambor)
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 74 72 80))), -$rr, -$rr, (2 * $rr), (2 * $rr))
                    $g.DrawEllipse((New-Object System.Drawing.Pen((C 28 26 30), 3)), -$rr, -$rr, (2 * $rr), (2 * $rr))
                    for ($i = 0; $i -lt 6; $i++) {
                        $an = $i * [Math]::PI / 3; $px = [Math]::Cos($an) * $rr * 0.58; $py = [Math]::Sin($an) * $rr * 0.58; $cr = $rr * 0.3
                        if ($i -lt $script:balas) {
                            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 222 178 70))), [float]($px - $cr), [float]($py - $cr), [float](2 * $cr), [float](2 * $cr))
                            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 196 110 62))), [float]($px - $cr * 0.5), [float]($py - $cr * 0.5), [float]$cr, [float]$cr)
                        } else { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 18 16 20))), [float]($px - $cr), [float]($py - $cr), [float](2 * $cr), [float](2 * $cr)) }
                    }
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 38 44))), -4, -4, 8, 8)
                    $g.Restore($st)
                    # cartuchera de cuero con las 6 balas y el marcador de duelos
                    $cin = Ruta-Redonda 10 280 150 26 6
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 60 30))), $cin); $g.DrawPath((New-Object System.Drawing.Pen((C 44 22 8), 2)), $cin); $cin.Dispose()
                    $cos = New-Object System.Drawing.Pen((ARGB 150 230 190 130), 1); $cos.DashStyle = 'Dash'; $g.DrawLine($cos, 14, 283, 156, 283); $g.DrawLine($cos, 14, 302, 156, 302); $cos.Dispose()
                    for ($i = 0; $i -lt 6; $i++) {
                        $bx = 20 + $i * 23
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 82 42 18))), $bx - 2, 285, 16, 17)
                        if ($i -lt $script:balas) {
                            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 226 182 74))), $bx, 278, 12, 22)
                            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 196 110 62))), $bx, 272, 12, 12)
                            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 255 246 200))), ($bx + 2), 280, 3, 18)
                        }
                    }
                    Texto-Color $g "DUELOS  $($script:duelosG) - $($script:duelosP)" 'EdmundMcMillen_INTLv4' 15 172 283 (C 255 214 120) (C 30 14 6) 4
                    Texto-Color $g "DISPAROS: $($script:disparos)" 'EdmundMcMillen_INTLv4' 13 300 285 (C 250 236 205) (C 30 14 6) 3
                }
            }
            Pintar-Burbuja $g $k
            Pintar-Flotantes $g
        }
        default {
            $scan = New-Object System.Drawing.Pen((C 28 0 0), 1)
            for ($y = 54; $y -lt $H; $y += 4) { $g.DrawLine($scan, 2, $y, $W - 2, $y) }
            $scan.Dispose()
            $g.DrawString($k.Titulo, (FntP($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($k.Sombra)), 15, 10)
            $pen2 = New-Object System.Drawing.Pen($k.Borde, 2)
            $g.DrawLine($pen2, 0, 52, $W, 52); $pen2.Dispose()
        }
    }
    if ($script:glitching) {
        for ($i = 0; $i -lt 6; $i++) {
            $col = @((C 255 0 0), (C 255 255 255), (C 0 255 255), (C 80 0 0))[$Rnd.Next(4)]
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($col)), $Rnd.Next(-50, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 300), $Rnd.Next(1, 7))
        }
    }
    $ancho = if ($k.Estilo -in @('tele', 'mew', 'oeste', 'culto', 'kaiju', 'femta')) { 4 } else { 3 }
    $pen = New-Object System.Drawing.Pen($k.Borde, $ancho)
    $g.DrawRectangle($pen, 1, 1, $W - 3, $H - 3); $pen.Dispose()
})

$script:drag = $false
# ¿hay un personaje dibujado bajo el ratón?
function Actor-En-Raton {
    if ($script:actores.Count -eq 0) { return $null }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    foreach ($a in @($script:actores.Values)) { $r = $a.Rect; if ($a.Visible -and $x -ge $r[0] -and $x -le ($r[0] + $r[2]) -and $y -ge $r[1] -and $y -le ($r[1] + $r[3])) { return $a.Id } }
    return $null
}
function Clic-Actor($id) {
    if (Ocupado) { return }
    switch ($script:skin.Estilo) {
        'culto' { if ($id -eq 'L') { Cordero-Clic } else { Cabra-Clic } }
        'kaiju' { Kaiju-Ataque $id }
        'zorro' { Averi-Clic }
        'mew' { Golpe-Guillotina }
        'oeste' { Zodiac-Clic }
        'pressure' { Sebastian-Clic }
        'dod' { Pursuer-Clic }
        'teto' { Teto-Clic }
        'enfosi' { Enfosi-Clic $id }
        'femta' { Token-Clic }
        'pop' { Tetra-Clic }
        'pizza' { Kevin-Clic }
        'punk' { Ky-Clic }
        'gran' { Gran-Clic }
        'abismo' { if ($id -eq 'M') { Nn-Mitty } else { Nn-Clic } }
        'historia' { Mk-Clic }
        'lobo' { Ag-Clic }
        'arana' { Vv-Clic }
        'clima' { Wg-Clic }
        'pintor' { Pr-Clic }
        'evil' { Es-Clic }
        'niebla' { if ($id -eq 'G') { Sf-Gato } else { Sf-Clic } }
        'knight' { Kn-Clic }
        'corrupta' { if ($id -eq 'N') { El-Natillas } else { El-Pinchar } }
        'boneyard' { Dy-Clic }
    }
}
$mDown = {
    # Kevin: tocar su pizza (mala idea)
    if ($script:skin.Estilo -eq 'pizza' -and $_.Button -eq 'Left' -and (Pizza-En-Raton)) { Pizza-Tocar; return }
    # Kennyoung: botón de suscribirse del reproductor
    # Kennyoung: él forma parte de la imagen de la escena (izquierdo = clic en él; derecho = charla)
    if ($script:skin.Estilo -eq 'punk' -and (Ky-En-Escena)) { if ($_.Button -eq 'Right') { Iniciar-Discusion } else { Ky-Clic }; return }
    $id = Actor-En-Raton
    if ($id) { if ($_.Button -eq 'Right') { Iniciar-Discusion } else { Clic-Actor $id }; return }
    $script:drag = $true; $script:p0 = [System.Windows.Forms.Cursor]::Position; $script:f0 = $form.Location
    # Zodiac dispara a todo lo que se mueve... incluida la ventana
    if ($script:skin.Estilo -eq 'oeste' -and -not (Ocupado)) { Zodiac-Mover }
    if ($script:skin.Estilo -eq 'teto' -and -not (Ocupado) -and ([Environment]::TickCount - $script:tetoArrastre) -gt 8000) {
        $script:tetoArrastre = [Environment]::TickCount; Sonido 'wheee'; $script:tetoVozT = $script:tetoArrastre
        Decir (Azar @('¡Wheee~! ¡Me llevas de paseo!', '¡Wheee! ¡Más rápido! ...no, más despacio, que me mareo.', '¡Wheee~! ¡Como en el metro, pero sin metro!'))
    }
}
$mMove = {
    if ($script:actores.Count -gt 0 -and -not $script:drag) { $form.Cursor = $(if ((Actor-En-Raton) -or ($script:skin.Estilo -eq 'pizza' -and (Pizza-En-Raton)) -or ($script:skin.Estilo -eq 'punk' -and (Ky-En-Escena)) -or (Kn-Fight-En-Raton) -or (Ag-Monitor-En-Raton) -or ((Vv-Capullo-En-Raton) -ge 0) -or (Wg-Paraguas-En-Raton)) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }) }
    if ($script:drag -and -not $script:glitching) {
        $p = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($script:f0.X + $p.X - $script:p0.X), ($script:f0.Y + $p.Y - $script:p0.Y))
        if ($script:inv) { Colocar-Invitado }   # el invitado viaja pegado al panel
    }
}
$mUp = { $script:drag = $false }
$form.Add_MouseDown($mDown); $form.Add_MouseMove($mMove); $form.Add_MouseUp($mUp)

function Cargar-Img($rel) {
    if (-not $rel) { return $null }
    $ruta = Ruta $rel
    if (Test-Path $ruta) { return [System.Drawing.Image]::FromFile($ruta) }
    return $null
}

function Construir-UI {
    $k = $Skins[$script:skinNombre]; $script:skin = $k
    # quitar las imágenes de la ventana antes de liberarlas (evita la ventana de error al cambiar de skin)
    $caraTimer.Stop(); $tvTimer.Stop(); $revTimer.Stop()
    Fin-Discusion $true
    if ($script:pb) { $script:pb.Image = $null; $form.Controls.Remove($script:pb); $script:pb.Dispose(); $script:pb = $null }
    foreach ($im in @($script:imgs.Values)) { if ($im) { $im.Dispose() } }
    foreach ($set in @($script:caras.Values)) { foreach ($im in $set) { if ($im) { $im.Dispose() } } }
    $script:imgs = @{}; $script:caras = @{}
    if ($script:tvRuido) { $script:tvRuido.Dispose(); $script:tvRuido = $null }
    $script:urlLbl = $null
    $script:gHP = 400; $script:gMax = 400; $script:gFase2 = $false; $script:gVivo = $true
    $snTimer.Stop(); $fxTimer.Stop(); $humoTimer.Stop(); $script:snApuntando = $false; $script:hits.Clear(); $script:flash = 0
    $script:balas = 6
    $script:telarana = $null; $telTimer.Stop(); $script:hambre = 0; $script:salto = 0
    $script:gComidos = 0; $script:disparos = 0; $script:agujeros2.Clear(); $script:fogonazo = 0
    $script:modoTienda = $false; $script:toques = 0; $script:enfadoFx = 0; $script:destello = 0
    $script:acechando = $false; $acechoTimer.Stop(); $script:zarpas.Clear(); $script:ondas.Clear(); $script:gotas.Clear(); $script:rojoFx = 0
    $script:pajaros.Clear(); $script:birdbrains = 0; $script:duelo = $null; $script:tkCd = 1
    # personajes dibujados y estado de las skins nuevas
    $actTimer.Stop(); $kRevTimer.Stop()
    if ($k.Estilo -ne 'gran') { Gran-Musica-Off }
    if ($k.Estilo -ne 'historia') { Mk-Musica-Off }
    if ($k.Estilo -ne 'lobo') { Ag-Musica-Off }
    if ($k.Estilo -ne 'arana') { Vv-Musica-Off }
    if ($k.Estilo -ne 'clima') { Wg-Musica-Off; if ($script:wgPortada) { $script:wgPortada.Dispose(); $script:wgPortada = $null } }
    if ($k.Estilo -ne 'pintor') { Pr-Musica-Off; Pr-Voz-Off }
    if ($k.Estilo -ne 'punk') { Ky-Musica-Off }
    if ($k.Estilo -ne 'pop') { Tetra-Musica-Off; $script:popBaila = 0 }
    Quitar-Actores
    if ($script:bmpEscena) { $script:bmpEscena.Dispose(); $script:bmpEscena = $null }
    $script:fe = 60; $script:seguidores = 0; $script:ritualFx = 0
    Kaiju-Reiniciar
    $script:antojo = 0
    $script:pzFx = 0; $script:pzQueso = $false; $script:pzEnfado = 0.0; $script:pzGrito = $null; $script:pzLluvia.Clear()
    if ($script:ky) { $script:ky.Fx = 0; $script:ky.Conc = 0; $script:ky.Flash = 0; $script:ky.Amp = 0.0 }
    if ($script:pzReparto -gt 0) { $script:pzReparto = 0; $script:pzTrozos = 8 }
    $form.Controls.Clear()

    $T = if ($k.Top) { $k.Top } else { 0 }
    $conActores = [bool]$k.Actores
    $conGif = [bool]$k.Gif -and -not $conActores
    $W = if ($k.Ancho) { $k.Ancho } elseif ($conGif) { 616 } else { 408 }
    $form.Size = New-Object System.Drawing.Size($W, $k.Alto)
    $form.BackColor = $k.Fondo
    $form.Opacity = (Opacidad-Base)
    $form.Text = $script:skinNombre

    $xTit = if ($k.TituloX) { $k.TituloX } elseif ($k.Estilo -eq 'web') { 48 } else { 12 }   # TituloX: deja sitio a un logo a la izquierda
    $estiloTit = if ($k.FuenteTitulo -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $titulo = New-Object System.Windows.Forms.Label
    $titulo.Text = $k.Titulo
    $titulo.Font = Fnt($k.FuenteTitulo, 20, $estiloTit)
    $titulo.ForeColor = $k.TituloColor
    $titulo.BackColor = [System.Drawing.Color]::Transparent
    $titulo.UseMnemonic = $false   # para que se vea el "&" de CORDERO & CABRA
    $titulo.AutoSize = $true
    $titulo.Location = New-Object System.Drawing.Point($xTit, 6)
    # las fuentes de Mewgenics solo se ven con el dibujado de GDI+
    $privada = [bool](@($k.FuenteTitulo, $k.Fuente, $k.BurFuente) | Where-Object { $_ -and $script:fuentesPriv.ContainsKey($_) })

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $k.Sub
    $sub.Font = Fnt($(if ($k.Fuente -eq 'Impact') { 'Segoe UI' } else { $k.Fuente }), 8, [System.Drawing.FontStyle]::Bold)
    $sub.ForeColor = $k.SubColor
    $sub.BackColor = [System.Drawing.Color]::Transparent
    $sub.AutoSize = $true
    if ($privada) { $titulo.UseCompatibleTextRendering = $true; $sub.UseCompatibleTextRendering = $true }
    $form.Controls.AddRange(@($titulo, $sub))
    $xSub = if ($k.TituloImg) { 166 } else { $xTit + [int]($titulo.PreferredWidth / $script:K) + 2 }
    $sub.Location = New-Object System.Drawing.Point($xSub, 26)
    foreach ($c in @($titulo, $sub)) { $c.Add_MouseDown($mDown); $c.Add_MouseMove($mMove); $c.Add_MouseUp($mUp) }

    $script:bi = 0
    $bCerrar = Nuevo-Boton 'X' ($W - 40) 12 28 28; $bCerrar.ForeColor = $k.BarraBtnTexto
    $bCerrar.Add_Click({ $form.Close() })
    $txtMin = if ($k.Fuente -eq 'Impact') { '–' } else { '_' }
    $bMin = Nuevo-Boton $txtMin ($W - 74) 12 28 28; $bMin.ForeColor = $k.BarraBtnTexto
    $bMin.Add_Click({ $form.WindowState = 'Minimized' })
    $bSkins = Nuevo-Boton 'Skins' ($W - 150) 12 70 28; $bSkins.ForeColor = $k.BarraBtnTexto
    # el menú Skins se abre en el grupo de la skin que llevas puesta
    $bSkins.Add_Click({ if (-not (Ocupado)) { $script:modoSkins = -not $script:modoSkins; if ($script:modoSkins) { $script:pagSkins = Pagina-De-Skin $script:skinNombre }; Mostrar-Pagina } })
    $bAjustes = Nuevo-Boton 'Ajustes' ($W - 226) 12 72 28; $bAjustes.ForeColor = $k.BarraBtnTexto
    $bAjustes.Add_Click({ Mostrar-Ajustes })
    $form.Controls.Add($bAjustes)
    if ($k.Estilo -in @('hacker', 'mlg', 'gunsaw')) { Hover-Color $bAjustes }

    $script:grid = New-Object System.Windows.Forms.Panel
    $grid.Location = New-Object System.Drawing.Point(16, (66 + $T))
    $grid.Size = New-Object System.Drawing.Size(376, 168)
    $grid.BackColor = [System.Drawing.Color]::Transparent

    $script:lblPag = New-Object System.Windows.Forms.Label
    $lblPag.ForeColor = $k.StatusColor
    $lblPag.BackColor = [System.Drawing.Color]::Transparent
    $lblPag.Font = Fnt($(if ($k.Fuente -eq 'Impact') { 'Impact' } else { $k.Fuente }), 10, $(if ($k.Fuente -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }))
    $lblPag.TextAlign = 'MiddleCenter'
    $lblPag.Location = New-Object System.Drawing.Point(140, (242 + $T))
    $lblPag.Size = New-Object System.Drawing.Size(128, 28)
    if ($privada) { $lblPag.UseCompatibleTextRendering = $true }

    $bAnt = Nuevo-Boton '<' 16 (242 + $T) 120 28
    # < y > pasan de página; en el menú Skins pasan de grupo (y dan la vuelta)
    $bAnt.Add_Click({
        if ($script:modoSkins) { $n = (Paginas-Skins).Count; $script:pagSkins = ($script:pagSkins - 1 + $n) % $n; Mostrar-Pagina }
        elseif ($script:pagina -gt 0) { $script:pagina--; Mostrar-Pagina }
    })
    $bSig = Nuevo-Boton '>' 272 (242 + $T) 120 28
    $bSig.Add_Click({
        if ($script:modoSkins) { $n = (Paginas-Skins).Count; $script:pagSkins = ($script:pagSkins + 1) % $n; Mostrar-Pagina }
        elseif ($script:pagina -lt $totalPaginas - 1) { $script:pagina++; Mostrar-Pagina }
    })

    $script:status = New-Object System.Windows.Forms.Label
    $status.ForeColor = $k.StatusColor
    $form.Controls.AddRange(@($bSkins, $bMin, $bCerrar, $grid, $bAnt, $lblPag, $bSig, $status))
    if ($k.Estilo -in @('hacker', 'mlg', 'gunsaw')) { foreach ($b in @($bSkins, $bMin, $bCerrar, $bAnt, $bSig)) { Hover-Color $b } }

    if ($k.Estilo -eq 'web') {
        $candado = New-Object System.Windows.Forms.Label
        $candado.Text = '🔒'
        $candado.Font = Fnt('Segoe UI Symbol', 9)
        $candado.ForeColor = (C 30 140 60)
        $candado.BackColor = [System.Drawing.Color]::White
        $candado.Location = New-Object System.Drawing.Point(100, 63)
        $candado.Size = New-Object System.Drawing.Size(20, 19)
        $script:urlLbl = New-Object System.Windows.Forms.Label
        $urlLbl.Text = $k.Url
        $urlLbl.Font = Fnt('Segoe UI', 9)
        $urlLbl.ForeColor = (C 40 40 40)
        $urlLbl.BackColor = [System.Drawing.Color]::White
        $urlLbl.Location = New-Object System.Drawing.Point(121, 64)
        $urlLbl.Size = New-Object System.Drawing.Size(($W - 142), 18)
        $form.Controls.AddRange(@($candado, $urlLbl))
    }

    if ($conActores) {
        # personajes grandes dibujados en el panel y bocadillo transparente encima del dibujo
        foreach ($def in $k.Actores) { Nuevo-Actor $def }
        if ($k.Estilo -eq 'enfosi') { Enfosi-Reset } else { $script:ef = $null }
        if ($k.Estilo -eq 'gran') { Gran-Reset } else { $script:gr = $null }
        # Nanachi: se guarda lo que lleva (estofados, mullido); al irse se liberan sus caras y la olla
        if ($k.Estilo -eq 'abismo') { Nn-Reset } else { Nn-Liberar; if ($script:nnOlla) { $script:nnOlla.Dispose(); $script:nnOlla = $null } }
        # Velvet: guarda su seda, su hambre y sus capullos mientras se cambia de skin (la trampa se cancela)
        if ($k.Estilo -eq 'arana') { Vv-Reset; $script:vv.TrampaT = 0; $script:vv.Mueve = -1 }
        # Weathergirl: guarda el tiempo y las palabras sin decir; el fondo se pinta con el cielo que toque
        if ($k.Estilo -eq 'clima') { Wg-Reset; $script:wg.Pintado = '' }
        # Painter: guarda el calor y el paisaje mientras se cambia de skin (la minería se cancela)
        if ($k.Estilo -eq 'pintor') { Pr-Reset; $script:pr.Mina = 0; $script:pr.CaraHasta = 0; $script:pr.Hex.Clear(); $script:pr.Saludado = $false }
        # Angela: guarda la energía, el Qliphoth y la brecha mientras se cambia de skin; al irse se sueltan sus imágenes
        if ($k.Estilo -eq 'lobo') { Ag-Reset; $script:ag.FiltroT = 0; $script:ag.Cara = 'main'; $script:ag.CaraHasta = 0 } else { Ag-Liberar }
        # Malkuth: guarda sus libros, su emoción y su ánimo; al irse se suelta la carta de la Realización
        if ($k.Estilo -eq 'historia') { Mk-Reset; $script:mk.Respira = 0; $script:mk.EgoT = 0; $script:mk.Ultima = [Environment]::TickCount; Mk-Base } elseif ($script:mkEgo) { $script:mkEgo.Dispose(); $script:mkEgo = $null }
        # Evil Scary: guarda su distancia y sus contadores; al irse se borra todo y se suelta la cara del susto
        if ($k.Estilo -eq 'evil') { Es-Reset } else { $script:es = $null; if ($script:esSusto) { $script:esSusto.Dispose(); $script:esSusto = $null } }
        # Soft Fuzzy Man: guarda su existencia y sus contadores mientras sea la skin activa
        if ($k.Estilo -eq 'niebla') { Sf-Reset } else { $script:sf = $null }
        if ($k.Estilo -eq 'knight') { Kn-Reset } else { $script:kn = $null }
        # Ellie: guarda su rabia y sus contadores mientras sea la skin activa; sus copias de color se hacen al dibujarla
        if ($k.Estilo -eq 'corrupta') { El-Reset } else { $script:el = $null; foreach ($im in @($script:elRojo, $script:elCian)) { if ($im) { $im.Dispose() } }; $script:elRojo = $null; $script:elCian = $null }
        # Dybbuk: guarda su vida y su maná mientras sea la skin activa
        if ($k.Estilo -eq 'boneyard') { Dy-Reset; Dy-Base } else { $script:dy = $null }
        $status.BackColor = [System.Drawing.Color]::Transparent
        $status.ForeColor = $k.BurTexto
        $status.UseMnemonic = $false
        if ($privada) { $status.UseCompatibleTextRendering = $true }
        $tamBur = if ($k.BurFuente -eq 'Segoe Print') { 8 } elseif ($k.BurFuente -eq 'TikaFont Adjusted') { 9.5 } else { 9 }
        $status.Font = Fnt($k.BurFuente, $tamBur, [System.Drawing.FontStyle]::Bold)
        $status.Location = New-Object System.Drawing.Point($k.Burbuja[0], $k.Burbuja[1])
        $status.Size = New-Object System.Drawing.Size($k.Burbuja[2], $k.Burbuja[3])
        $status.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $script:ultimoTick = [Environment]::TickCount; $actTimer.Start()
    }
    if ($conGif) {
        $script:imgs = @{ main = (Cargar-Img $k.Gif); clic = (Cargar-Img $k.GifClic); raro = (Cargar-Img $k.GifRaro); fase2 = (Cargar-Img $k.GifFase2); titulo = (Cargar-Img $k.TituloImg) }
        if ($k.Extra) { foreach ($e in $k.Extra.Keys) { $script:imgs[$e] = Cargar-Img $k.Extra[$e] } }
        if ($k.Caras) { foreach ($c in $k.Caras.Keys) { $script:caras[$c] = @((Cargar-Img $k.Caras[$c][0]), (Cargar-Img $k.Caras[$c][1])) } }
        $script:pb = New-Object System.Windows.Forms.PictureBox
        $pb.SizeMode = 'Zoom'
        $pb.Cursor = 'Hand'
        $pb.Image = if ($script:caras.Count -gt 0) { $script:caras.cerrados[0] } else { $script:imgs.main }
        $pb.Location = New-Object System.Drawing.Point($k.Pb[0], $k.Pb[1])
        $pb.Size = New-Object System.Drawing.Size($k.Pb[2], $k.Pb[3])
        $pb.BackColor = if ($k.PbFondo) { $k.PbFondo } else { [System.Drawing.Color]::Transparent }
        if ($k.PbBorde) { $pb.BorderStyle = 'FixedSingle' }
        # clic derecho sobre el personaje: empieza una discusión
        $pb.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $pb.Add_Click({
            if ($_.Button -eq 'Right') { return }
            $k = $script:skin
            switch ($k.Estilo) {
                'tele' { Cara 'clic' 3000; Decir (Azar $k.Clic) }
                'mew' { Golpe-Guillotina }
                'culto' { Cordero-Clic }
                'kaiju' { Kaiju-Ataque 'P' }
                'zorro' { Averi-Clic }
                'mlg' { }   # Mikaela dispara al soltar el ratón (Snipe)
                'gunsaw' {
                    if ($k.Telarana) {
                        $presa = Velvet-Escupir
                        if ($presa) { Decir "$(Azar $k.Clic) ($presa ha quedado atrapado)" }
                    } elseif ($k.Hambre) { Dune-Comer }
                }
                'oeste' {
                    if ($script:balas -lt 6) {
                        $script:balas = 6; Cara 'recarga' 1500; Sonido 'loco'
                        Decir '*Recarga el revólver.* Seis balas. Que empiece el baile.'
                        $form.Invalidate()
                    } else { Cara 'pose' 3000; Decir (Azar $k.Clic) }
                }
                default { Decir (Azar $k.Clic) 'abiertos' }
            }
        })
        if ($k.Estilo -eq 'mlg') {
            # Snipe: mantener pulsado para cargar, soltar para disparar
            $pb.Cursor = 'Cross'
            $pb.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:snPos = $_.Location; Snipe-Inicio } })
            $pb.Add_MouseMove({ $script:snPos = $_.Location; if ($script:snApuntando) { $this.Invalidate() } })
            $pb.Add_MouseUp({ if ($_.Button -eq 'Left') { $script:snPos = $_.Location; Snipe-Disparo } })
            $pb.Add_Paint({
                $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'
                if ($script:snApuntando) {
                    $x = $script:snPos.X; $y = $script:snPos.Y
                    $rojo = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2)
                    $g.DrawEllipse($rojo, ($x - 22), ($y - 22), 44, 44)
                    $g.DrawLine($rojo, ($x - 30), $y, ($x - 8), $y); $g.DrawLine($rojo, ($x + 8), $y, ($x + 30), $y)
                    $g.DrawLine($rojo, $x, ($y - 30), $x, ($y - 8)); $g.DrawLine($rojo, $x, ($y + 8), $x, ($y + 30))
                    $g.FillEllipse([System.Drawing.Brushes]::Red, ($x - 3), ($y - 3), 6, 6)
                    $rojo.Dispose()
                }
                foreach ($h in $script:hits) {
                    Dibujar-Hit $g $h.X $h.Y (12 * $script:K)
                    $g.DrawString('+100', (Fnt('Arial Black', 9)), [System.Drawing.Brushes]::Lime, ($h.X + 12), ($h.Y - 24 + $h.T))
                }
                if ($script:flash -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($script:flash * 50, 255, 255, 255))), 0, 0, $this.Width, $this.Height) }
            })
        }
        if ($k.Estilo -eq 'tele') { $script:tvRuido = Nuevo-Ruido 64 48 }

        $status.BackColor = $k.BurFondo
        $status.ForeColor = $k.BurTexto
        $status.BorderStyle = 'FixedSingle'
        $status.Padding = New-Object System.Windows.Forms.Padding(4)
        $tamBur = if ($k.BurFuente -eq 'Segoe Print') { 8 } else { 9 }
        $status.Font = Fnt($k.BurFuente, $tamBur, [System.Drawing.FontStyle]::Bold)
        $status.Location = New-Object System.Drawing.Point($k.Burbuja[0], $k.Burbuja[1])
        $status.Size = New-Object System.Drawing.Size($k.Burbuja[2], $k.Burbuja[3])
        $form.Controls.Add($pb)
    } elseif (-not $conActores) {
        $status.BackColor = [System.Drawing.Color]::Black
        $status.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $status.Font = Fnt('Consolas', 8.5)
        $status.Location = New-Object System.Drawing.Point(14, 278)
        $status.Size = New-Object System.Drawing.Size(380, 22)
    }

    Montar-Caja-Texto
    # todo se diseña a tamaño base y luego se escala de una vez (evita textos cortados)
    $loc = $form.Location
    Escalar $form
    $form.Location = $loc
    Mostrar-Pagina
    $script:twTexto = ''; $script:twPos = 0; $status.Text = ''; $script:twBloqueo = 0
    $form.Invalidate()
}

Construir-UI
# recordar dónde estaba la ventana
if ($script:aj.Posicion -and $script:aj.X -ne '' -and $script:aj.Y -ne '') {
    $pt = New-Object System.Drawing.Point([int]$script:aj.X, [int]$script:aj.Y)
    if ([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.WorkingArea.Contains($pt) }) { $form.StartPosition = 'Manual'; $form.Location = $pt }
}
$form.Add_FormClosing({ if ($form.WindowState -eq 'Normal') { $script:aj.X = $form.Left; $script:aj.Y = $form.Top }; Guardar-Ajustes })
# ================= AVISO DE EPILEPSIA (sale cada vez que se abre el panel) =================
# Fondo negro con la imagen skins\logo\aviso.jpg muy oscurecida, el aviso en letras grandes y dos botones.
# Mientras está, el panel cuenta como "ocupado" (no habla ni cambia de skin). Al cerrarlo sigue el arranque normal.
$script:avisoOv = $null; $script:avisoImg = $null
function Mostrar-Aviso {
    $script:transicion = $true
    $script:avisoImg = Cargar-Img 'skins\logo\aviso.jpg'
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0); $ov.Size = $form.ClientSize; $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $ov.Add_Paint({ $_.Graphics.ScaleTransform($script:K, $script:K); Pintar-Aviso $_.Graphics ([int]($this.Width / $script:K)) ([int]($this.Height / $script:K)) })
    $W = [int]($ov.Width / $script:K); $H = [int]($ov.Height / $script:K)
    # botones: activar el modo seguro (o ya activado) y continuar
    $b1 = New-Object System.Windows.Forms.Button; $b2 = New-Object System.Windows.Forms.Button
    foreach ($b in @($b1, $b2)) {
        $b.FlatStyle = 'Flat'; $b.Font = Fnt('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold); $b.Cursor = 'Hand'
        $b.FlatAppearance.BorderSize = [Math]::Max(1, [int](2 * $script:K)); $b.Size = New-Object System.Drawing.Size([int](210 * $script:K), [int](34 * $script:K))
    }
    $b1.Location = New-Object System.Drawing.Point([int](($W / 2 - 220) * $script:K), [int](($H - 52) * $script:K))
    $b2.Location = New-Object System.Drawing.Point([int](($W / 2 + 10) * $script:K), [int](($H - 52) * $script:K))
    Aviso-Botones $b1 $b2
    $b1.Add_Click({ $script:aj.Epilepsia = -not $script:aj.Epilepsia; Guardar-Ajustes; Aviso-Botones $this $script:avisoB2; $script:avisoOv.Invalidate() })
    $b2.Add_Click({ Cerrar-Aviso })
    $script:avisoB2 = $b2
    $ov.Controls.AddRange(@($b1, $b2))
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:avisoOv = $ov
}
function Aviso-Botones($b1, $b2) {
    if ($script:aj.Epilepsia) {
        $b1.Text = '✔  MODO SEGURO: SÍ'; $b1.BackColor = (C 40 140 70); $b1.ForeColor = [System.Drawing.Color]::White; $b1.FlatAppearance.BorderColor = (C 140 230 160)
    } else {
        $b1.Text = 'ACTIVAR MODO SEGURO'; $b1.BackColor = (C 255 210 40); $b1.ForeColor = [System.Drawing.Color]::Black; $b1.FlatAppearance.BorderColor = [System.Drawing.Color]::White
    }
    $b2.Text = 'CONTINUAR  ▶'; $b2.BackColor = (C 24 24 28); $b2.ForeColor = [System.Drawing.Color]::White; $b2.FlatAppearance.BorderColor = [System.Drawing.Color]::White
}
function Pintar-Aviso($g, $W, $H) {
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Black)
    # la imagen de fondo, muy oscura para que se lea bien el texto
    if ($script:avisoImg) { [void](Dibujar-Cubriendo $g $script:avisoImg $W $H 1.0 0.5 0.4) }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 200 0 0 0))), 0, 0, $W, $H)
    # franjas amarillas y negras de peligro arriba y abajo
    foreach ($y in @(0, ($H - 8))) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 210 40))), 0, $y, $W, 8)
        for ($x = -10; $x -lt $W; $x += 22) { $g.FillPolygon([System.Drawing.Brushes]::Black, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF($x, ($y + 8))), (New-Object System.Drawing.PointF(($x + 8), $y)), (New-Object System.Drawing.PointF(($x + 16), $y)), (New-Object System.Drawing.PointF(($x + 8), ($y + 8))))) }
    }
    # ⚠ ALERTA en grande
    $t1 = '⚠  ALERTA  ⚠'; $f1 = FntP('Segoe UI Symbol', 30, [System.Drawing.FontStyle]::Bold)
    $w1 = $g.MeasureString($t1, $f1).Width
    $g.DrawString($t1, $f1, (New-Object System.Drawing.SolidBrush((C 255 210 40))), [float]($W / 2 - $w1 / 2), 18)
    $t2 = 'EPILEPSIA FOTOSENSIBLE'; $f2 = FntP('Arial Black', 15)
    $w2 = $g.MeasureString($t2, $f2).Width
    $g.DrawString($t2, $f2, [System.Drawing.Brushes]::White, [float]($W / 2 - $w2 / 2), 72)
    # el mensaje
    $msg = "Este programa tiene luces que parpadean, destellos de colores y pantallas que tiemblan. Su creador NO puede controlarlos.`n`nSi tienes epilepsia o te molestan las luces, activa el MODO SEGURO."
    $fm = New-Object System.Drawing.StringFormat; $fm.Alignment = 'Center'
    $g.DrawString($msg, (FntP('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 236 236 236))), (New-Object System.Drawing.RectangleF(30, 106, ($W - 60), ($H - 176))), $fm)
    $g.DrawString('Puedes cambiarlo cuando quieras en Ajustes.', (FntP('Segoe UI', 8.5, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((C 170 170 170))), (New-Object System.Drawing.RectangleF(30, ($H - 76), ($W - 60), 18)), $fm)
}
function Cerrar-Aviso {
    if ($script:avisoOv) { $form.Controls.Remove($script:avisoOv); $script:avisoOv.Dispose(); $script:avisoOv = $null }
    if ($script:avisoImg) { $script:avisoImg.Dispose(); $script:avisoImg = $null }
    $script:transicion = $false
    Arranque
}
# lo que pasa al abrir el panel, después del aviso
function Arranque {
    # primero el logo de JOSEPABLINI CORPORATION y luego la intro de la skin (en modo seguro, sin intros)
    if ($script:aj.Intros -and -not $script:aj.Epilepsia) { Logo-Inicio } else { Efecto-Entrada $null }
    # la primera vez que se abre el panel sale la guía del panda
    if (-not $script:aj.Guia) { $script:guiaCalma = 0; $guiaInicio.Start() }
}

$form.Add_Shown({
    $twTimer.Start(); $idleTimer.Start(); $ambTimer.Start(); $hambreTimer.Start()
    Aplicar-Ajustes
    # siempre sale antes el aviso de epilepsia; al cerrarlo, Arranque sigue con el logo y la intro
    Mostrar-Aviso
})
[void]$form.ShowDialog()
