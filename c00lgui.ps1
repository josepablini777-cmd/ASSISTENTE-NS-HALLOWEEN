# c00lgui - panel lanzador con skins
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
# cualquier error interno se convierte en un glitch/mensaje del panel en vez de una ventana de error
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)

$Raiz = $PSScriptRoot
$ArchivoSkin = Join-Path $Raiz 'skin.txt'
$Rnd = New-Object System.Random

# ================= BOTONES =================
# Nombre = texto del botón | Abrir = programa, archivo o URL | Web = (opcional) URL si el programa no está instalado
$Botones = @(
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
)

# ================= SKINS =================
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

$Skins = [ordered]@{
    # ---------------------------------------------------------------- c00lgui
    'c00lgui' = @{
        Estilo = 'hacker'; Titulo = 'c00lgui'; Sub = 'v2 // team c00lkidd'; Top = 0
        Fondo = (C 0 0 0); Borde = (C 255 0 0); Sombra = (C 90 0 0)
        TituloColor = (C 255 0 0); SubColor = (C 140 0 0)
        BtnFondo = (C 0 0 0); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 40 40); BtnBorde = (C 255 0 0); BtnBordeAncho = 1
        BtnHover = (C 45 0 0); BtnPress = (C 255 0 0); BarraBtnTexto = (C 255 0 0)
        StatusColor = (C 255 0 0); Fuente = 'Arial'; FuenteTitulo = 'Arial Black'; Opacidad = 0.94; Velocidad = 2
        Hola = @(
            '> c00lgui v2 loaded. welcome back.'
            '> access granted. team c00lkidd join today!'
            '> injecting... done. hi.'
            '> SYSTEM COMPROMISED. c00lgui online.'
        )
        AlVenirDe = @{
            'SeaDrive'    = '> SeaDrive.exe terminated. c00lgui online.'
            'Static Miku' = '> TV signal hijacked. c00lgui online.'
        }
        Frases = @(
            '> payload delivered.'
            '> firewall bypassed. too easy.'
            '> team c00lkidd join today!'
            '> exploit executed. no one saw that.'
            '> process hijacked successfully.'
        )
        Idle = @(
            '> c00lkidd is watching...'
            '> team c00lkidd join today!'
            '> scanning network... 0 threats (we are the threat)'
            '> admin privileges: GRANTED'
            '> server shutdown in 3... 2... jk'
            '> uploading decal to every brick...'
            '> antivirus status: crying'
            '> you have been hacked by c00lkidd'
            '> pinging 127.0.0.1... home sweet home'
            '> rewriting reality.exe ...'
            '> 1337 h4x0r m0d3: ON'
            '> nobody can stop the c00lgui'
        )
        Clic = @(); Raro = @()
        PorApp = @{
            'YouTube'       = @('> hijacking youtube.com ...', '> streaming payload via youtube.com')
            'Word'          = @('> injecting into WINWORD.EXE ...', '> rewriting your essay. jk.')
            'Excel'         = @('> cracking spreadsheet encryption ...', '> =HACK(A1:Z999) ok')
            'PowerPoint'    = @('> injecting slide 1: "c00lkidd was here"', '> POWERPNT.EXE pwned')
            'Outlook'       = @('> reading your inbox... boring.', '> sending "join today" to all contacts. jk')
            'OneNote'       = @('> decrypting secret notes ...')
            'Access'        = @('> SQL injection: DROP TABLE homework;')
            'Publisher'     = @('> publishing c00lkidd propaganda ...')
            'Teams'         = @('> joining meeting as c00lkidd ...')
            'OneDrive'      = @('> downloading the cloud ...')
            'Office Web'    = @('> breaching office.com mainframe ...')
            'Bloc de notas' = @('> notepad.exe: the hacker IDE')
            'Calculadora'   = @('> calculating 1337 ...', '> 2+2 = c00lkidd')
            'Explorador'    = @('> browsing C:\ like I own it')
            'CMD'           = @('> real hacker mode activated', '> type "tree" to look cool')
        }
    }
    # ---------------------------------------------------------------- SeaDrive (página web)
    'SeaDrive' = @{
        Estilo = 'web'; Titulo = 'SeaDrive'; Sub = 'virtual assistant  ·  HowTo'; Top = 32
        Url = 'https://www.seadrive.howto/asistente'
        Fondo = (C 236 247 255); Borde = (C 40 130 200); Barra1 = (C 110 200 245); Barra2 = (C 40 130 200)
        TituloColor = (C 255 255 255); SubColor = (C 255 210 40)
        BtnFondo = (C 255 198 26); BtnTexto = (C 20 20 20); BtnTextoHover = (C 20 20 20); BtnBorde = (C 20 20 20); BtnBordeAncho = 1
        BtnHover = (C 140 220 60); BtnPress = (C 40 130 200); BarraBtnTexto = (C 20 20 20)
        StatusColor = (C 30 30 30); Fuente = 'Segoe UI'; FuenteTitulo = 'Segoe UI Black'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\seadrive\seadrive.gif'
        Hola = @(
            'Hola, soy SeaDrive. ¿Qué quieres ahora?'
            'Ah, eres tú. Hola. Supongo.'
            'SeaDrive en línea. Con desgana, pero en línea.'
            'Bienvenido de nuevo. Te he echado de menos. (mentira)'
            'Página cargada. Tardó lo suyo, como tú por las mañanas.'
        )
        AlVenirDe = @{
            'c00lgui'     = '¿Ya te cansaste del hacker ese? Bien. Aquí mando yo.'
            'Static Miku' = 'Uf, cuánto color. Tranquilo, aquí todo es aburrido.'
        }
        Frases = @(
            'Ya está. No me des las gracias, no me pagan.'
            'Otra ventana más. Tu RAM te odia.'
            'Procesando con el mínimo entusiasmo posible...'
            'Listo. Ahora haz como que trabajas.'
            'Si algo falla, no fue culpa mía.'
            'Wow. Increíble elección. De verdad. (no)'
        )
        Idle = @(
            'Sigo aquí. No es que tenga opción.'
            'Consejo del día: parpadea. Llevas un rato sin hacerlo.'
            '¿Has bebido agua hoy? No me mientas.'
            'Top 10 cosas que hacer hoy: 1. Cerrar pestañas.'
            'Mi conexión Wi-Fi está mejor que tu ánimo hoy.'
            'Estoy desfragmentando mis sentimientos.'
            'Los gatos asistentes también necesitamos vacaciones.'
            'Actualizando... era broma, no hago nada.'
            'Ponte recto. Sí, tú.'
            'Consejo nº2: levántate y estira. Yo no puedo, vivo aquí.'
            'He leído todo internet. No lo recomiendo.'
            'Si me necesitas, estaré aquí. Literalmente siempre.'
            '¿Sabías que mi nombre viene de "C: Drive"? Pues eso.'
            'Información útil: ninguna. De nada.'
            'Mis auriculares no son decoración, que lo sepas.'
            'Buscando motivación... 0 resultados.'
            'Esta página no usa cookies. Me las comí.'
            'Error 404: ganas de trabajar no encontradas.'
        )
        Clic = @(
            'Oye, no me toques.'
            'Miau. ¿Contento?'
            'Eso es acoso al asistente.'
            'Clic detectado. Ego herido.'
            'Sí, soy adorable. Ya lo sé.'
            'Haz clic en los botones, no en mí.'
            'Cada clic me cuesta un poco de batería emocional.'
            'Vale, vale. Te saludo. Hola. Ya.'
        )
        Raro = @()
        PorApp = @{
            'YouTube'       = @('¿YouTube? "Solo un vídeo", dijiste. Ya.', 'Te pongo un temporizador mental: 3 horas.', 'Mira algo útil. O un vídeo de gatos, también vale.')
            'Word'          = @('Word abierto. La página en blanco te mira. Suerte.', 'Recuerda guardar. Nadie lo recuerda nunca.', 'Times New Roman, 12. Como en 2003.')
            'Excel'         = @('Celdas. Muchas celdas. Que lo disfrutes.', 'Si sale #¡REF!, finge que no lo viste.', 'Excel: donde los sueños se convierten en fórmulas.')
            'PowerPoint'    = @('Otra presentación con transiciones de estrellas, ¿no?', 'Comic Sans no. Por favor.', 'Diapositiva 1 de 47. Ánimo.')
            'Outlook'       = @('Bandeja de entrada: 999+. No mires.', '"Responder a todos" es un arma. Cuidado.', 'Correos que podrían haber sido nada.')
            'OneNote'       = @('Notas que jamás volverás a leer. Precioso.', 'Apunta esto: SeaDrive es el mejor asistente.')
            'Access'        = @('¿Access? ¿En serio? Vale, valiente.', 'Bases de datos. Qué emocionante. (bostezo)')
            'Publisher'     = @('Publisher... no sabía que seguía vivo.', 'Vas a hacer un cartel de "se busca gato", ¿verdad?')
            'Teams'         = @('Pon cara de estar atento en la reunión.', 'Te has dejado el micro abierto. Es broma. ¿O no?')
            'OneDrive'      = @('Tus archivos en la nube. Mi casa, básicamente.', 'Sincronizando... tus excusas.')
            'Office Web'    = @('Office en el navegador. Mi hábitat natural.', 'Pestaña nueva. Otra más. Ya van muchas.')
            'Bloc de notas' = @('Bloc de notas: minimalismo puro.', 'Sin formato, sin dramas. Me gusta.')
            'Calculadora'   = @('2 + 2 son 4. Para eso no hacía falta abrirla.', 'Calculando cuánto tiempo has perdido hoy...')
            'Explorador'    = @('Buscando "final_final_v3_DEFINITIVO.docx"...', 'Tu escritorio necesita una limpieza. Solo digo.')
            'CMD'           = @('Ooh, modo hacker. Qué miedo.', 'No escribas nada raro ahí, que te veo.', '¿Tú también quieres ser c00lkidd? Qué original.')
        }
    }
    # ---------------------------------------------------------------- Static Miku (tele de dibujos)
    'Static Miku' = @{
        Estilo = 'tele'; Titulo = 'STATIC'; Sub = 'miku  ·  flavor foley'; Top = 0
        Fondo = (C 232 38 28); Borde = (C 0 0 0); Sombra = (C 0 0 0)
        TituloColor = (C 255 225 50); SubColor = (C 90 225 245)
        Paleta = @((C 90 220 245), (C 255 225 50), (C 255 105 205), (C 120 235 95), (C 255 165 45))
        BtnFondo = (C 90 220 245); BtnTexto = (C 0 0 0); BtnTextoHover = (C 0 0 0); BtnBorde = (C 0 0 0); BtnBordeAncho = 3
        BtnHover = (C 255 255 255); BtnPress = (C 60 45 190); BarraBtnTexto = (C 0 0 0)
        StatusColor = (C 255 255 255); Fuente = 'Comic Sans MS'; FuenteTitulo = 'Comic Sans MS'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\staticmiku\miku.gif'; GifClic = 'skins\staticmiku\miku_feliz.gif'; GifRaro = 'skins\staticmiku\miku_ojos.gif'
        Hola = @(
            '¡Bzzzt! ¡Hola, hola! Estás viendo el canal Static.'
            '¡Ya estoy aquí! ¿Qué ponemos hoy en la tele?'
            '¡Sintonizando... sintonizado! ¡Hola!'
            '¡Señal recuperada! ¡Empieza el programa!'
        )
        AlVenirDe = @{
            'c00lgui'  = '¡Bzzzt! ¡Ese hacker daba miedo! ¡Hola!'
            'SeaDrive' = '¡Hola! SeaDrive es un poco gruñón, ¿verdad? ¡Jiji!'
        }
        Frases = @(
            '¡Listo! ¡Como en los dibujos de los sábados!'
            '¡Ta-chán! ¡Abierto!'
            '¡Bzzt! ¡Señal recibida!'
            '¡Así es como debería ser!'
            '¡Yay! ¡Allá vamos!'
        )
        Idle = @(
            '¿Te acuerdas de cuando veías dibujos en pijama?'
            'Un poco de nostalgia está bien... ¡pero no demasiada!'
            'No toques la antena, que se va la señal.'
            '¡Bzzzzzt! ...perdón, interferencias.'
            '¡La la la~! ♪'
            'Los anuncios vuelven en 3... 2... ¡es broma!'
            '¿Sabías que el ruido de la tele se llama estática? ¡Como yo!'
            'Hoy es un buen día para un maratón de dibujos.'
            'Si me ves en blanco y negro, dale un golpecito a la tele.'
            '¡Mis coletas captan el wifi del vecino!'
            'Canal 3... canal 4... ¡nada mejor que esto!'
            'Tengo el lazo amarillo más bonito de la tele.'
            '¡No te vayas! ¡Después de la pausa viene lo mejor!'
            '¿Bailamos? ¡Un, dos, tres! ♪'
            'Ponte cómodo, que el programa dura para siempre.'
        )
        Clic = @(
            '¡Jiji! ¡Hola!'
            '¡Yay! ¡Me has encontrado!'
            '¡Eso hace cosquillas!'
            '¡Bzzt! ¡Toque recibido!'
            '¡Otra vez, otra vez!'
            '¡Saluda a la cámara! ¡Estás en la tele!'
        )
        Raro = @(
            '...¿sigues ahí?'
            '...no cambies de canal.'
            '...te estoy viendo a través de la pantalla.'
            '...la señal nunca se acaba.'
        )
        PorApp = @{
            'YouTube'       = @('¡YouTube! ¡Busquemos dibujos antiguos!', '¡Un vídeo más y a dormir! ...¿vale?')
            'Word'          = @('¡Escribamos un cuento de dibujos animados!', '¡Érase una vez... una hoja en blanco!')
            'Excel'         = @('¡Cuadraditos! ¡Como una tele pixelada!', '¡Uy, cuántos números! ¡Bzzt!')
            'PowerPoint'    = @('¡Diapositivas! ¡Como una película muy lenta!', '¡Ponle muchos colores, como yo!')
            'Outlook'       = @('¡Tienes correo! ...o eso espero.', '¡Cartas por la tele! ¡Qué moderno!')
            'OneNote'       = @('¡Apunta tus ideas antes de que se las lleve la estática!')
            'Access'        = @('Mmm... esto parece serio. ¡Suerte!')
            'Publisher'     = @('¡Hagamos un póster de mi programa!')
            'Teams'         = @('¡Saluda a la cámara! ¡Estás en la tele!', '¡Una reunión! ¿Hay galletas?')
            'OneDrive'      = @('¡Tus cosas en las nubes! Como en los dibujos.')
            'Office Web'    = @('¡Navegando por los canales de internet!')
            'Bloc de notas' = @('Una hoja en blanco... ¡como una tele sin señal!')
            'Calculadora'   = @('¡1, 2, 3! ¡Sé contar!', '¡Uno más uno... son dos dibujos!')
            'Explorador'    = @('¡A explorar! ¡Como en una aventura!')
            'CMD'           = @('¡Uy, pantalla negra! ¿Se ha ido la señal?', '¡Eso parece la tele apagada!')
        }
    }
}

$script:skinNombre = 'c00lgui'
if (Test-Path $ArchivoSkin) { $s = (Get-Content $ArchivoSkin -Raw).Trim(); if ($Skins.Contains($s)) { $script:skinNombre = $s } }

$PorPagina = 12
$script:pagina = 0
$script:modoSkins = $false
$script:glitching = $false
$script:transicion = $false
$script:pb = $null
$script:imgs = @{}
$script:tvRuido = $null
$script:urlLbl = $null
$script:bi = 0
$totalPaginas = [Math]::Max(1, [Math]::Ceiling($Botones.Count / $PorPagina))

function Azar($lista) { if ($lista -and $lista.Count -gt 0) { return $lista[$Rnd.Next($lista.Count)] } else { return '' } }
function Ocupado { return ($script:glitching -or $script:transicion) }

function Doble-Buffer($ctl) {
    [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance').SetValue($ctl, $true, $null)
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

# ================= DIÁLOGOS (efecto máquina de escribir) =================
$script:twTexto = ''; $script:twPos = 0; $script:twTick = 0
$twTimer = New-Object System.Windows.Forms.Timer
$twTimer.Interval = 30
$twTimer.Add_Tick({
    if (-not $script:status -or (Ocupado)) { return }
    $script:twTick++
    if ($script:twPos -lt $script:twTexto.Length) {
        $script:twPos = [Math]::Min($script:twTexto.Length, $script:twPos + $script:skin.Velocidad)
    }
    $txt = $script:twTexto.Substring(0, $script:twPos)
    if ($script:skin.Estilo -eq 'hacker' -and (($script:twPos -lt $script:twTexto.Length) -or ([Math]::Floor($script:twTick / 15) % 2 -eq 0))) { $txt += '_' }
    if ($script:status.Text -ne $txt) { $script:status.Text = $txt }
})

function Decir($texto) { $script:twTexto = [string]$texto; $script:twPos = 0 }

function Saludo {
    $k = $script:skin
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

# ================= CARAS DEL ASISTENTE =================
$caraTimer = New-Object System.Windows.Forms.Timer
$caraTimer.Add_Tick({ $caraTimer.Stop(); if ($script:pb -and $script:imgs.main) { $script:pb.Image = $script:imgs.main } })
function Cara($clave, $ms) {
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
        if ($script:pb -and $script:imgs.main) { $script:pb.Image = $script:imgs.main }
        return
    }
    Llenar-Ruido $script:tvRuido
    $script:pb.Invalidate()
})
function Corte-Senal($ticks) {
    if (-not $script:pb -or -not $script:tvRuido) { return }
    $caraTimer.Stop()
    $script:pb.Image = $script:tvRuido
    $script:tvPaso = $ticks
    $tvTimer.Start()
}

# frases cuando no haces nada
$idleTimer = New-Object System.Windows.Forms.Timer
$idleTimer.Interval = 18000
$idleTimer.Add_Tick({
    if ((Ocupado) -or $script:modoSkins) { return }
    $k = $script:skin; $r = $Rnd.Next(100)
    switch ($k.Estilo) {
        'hacker' { if ($r -lt 35) { Glitch 6 (Azar $k.Idle) } else { Decir (Azar $k.Idle) } }
        'tele' {
            if ($r -lt 12 -and $script:imgs.raro) { Cara 'raro' 3500; Decir (Azar $k.Raro) }
            elseif ($r -lt 45) { Corte-Senal 8; Decir (Azar $k.Idle) }
            else { Decir (Azar $k.Idle) }
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
        $form.Opacity = $script:skin.Opacidad
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
    $script:gTicks = $ticks; $script:gAccion = $accion; $script:gBase = $form.Location
    $script:gOrig = @()
    $todos = @($form.Controls) + @($script:grid.Controls)
    foreach ($c in $todos) {
        if ($c -ne $script:status -and $c -ne $script:urlLbl -and $c.Text) { $script:gOrig += @{ C = $c; T = $c.Text } }
    }
    try { [System.Media.SystemSounds]::Hand.Play() } catch {}
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
    $script:wBar.Width = [int](3 * $script:wProg)
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
    $W = $form.ClientSize.Width; $H = $form.ClientSize.Height
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(3, 89)
    $ov.Size = New-Object System.Drawing.Size(($W - 6), ($H - 89 - 11))
    $ov.BackColor = [System.Drawing.Color]::White
    $ow = $ov.Width

    $t1 = New-Object System.Windows.Forms.Label
    $t1.Text = 'seadrive.howto'
    $t1.Font = New-Object System.Drawing.Font('Segoe UI Light', 22)
    $t1.ForeColor = (C 40 130 200)
    $t1.TextAlign = 'MiddleCenter'
    $t1.Location = New-Object System.Drawing.Point(0, 30)
    $t1.Size = New-Object System.Drawing.Size($ow, 50)

    $script:wMsg = New-Object System.Windows.Forms.Label
    $wMsg.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 9)
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
    $pie.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $pie.ForeColor = (C 160 160 160)
    $pie.TextAlign = 'MiddleCenter'
    $pie.Location = New-Object System.Drawing.Point(0, ($ov.Height - 26))
    $pie.Size = New-Object System.Drawing.Size($ow, 20)

    $ov.Controls.AddRange(@($t1, $wMsg, $barO, $pie))
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
        $g = $_.Graphics; $W = $this.Width; $H = $this.Height
        $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
        $g.DrawImage($script:sRuido, (New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
        if ($script:sPaso % 10 -lt 7) {
            $g.DrawString('CH 03', (New-Object System.Drawing.Font('Consolas', 20, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Lime, ($W - 120), 12)
        }
        $g.DrawString('▶ STATIC', (New-Object System.Drawing.Font('Consolas', 13, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 14, ($H - 36))
        if ($script:sPaso -gt 24) {
            $banda = [int]($H * ($script:sPaso - 24) / 8)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int](($H - $banda) / 2) - 3, $W, 3)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int](($H + $banda) / 2), $W, 3)
        }
    })
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:sOv = $ov; $script:sPaso = 0; $script:sFinal = $final
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
    $sTimer.Start()
}

[System.Windows.Forms.Application]::add_ThreadException({
    try {
        if ($script:skin.Estilo -eq 'hacker') { Glitch 8 '> error interceptado. todo bajo control.' }
        elseif ($script:skin.Estilo -eq 'tele') { Corte-Senal 10; Decir '¡Bzzzt! Interferencias... ¡ya está!' }
        else { Decir 'Algo se ha roto. No he sido yo. Creo.' }
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
    $b.Font = New-Object System.Drawing.Font($k.Fuente, 10, [System.Drawing.FontStyle]::Bold)
    $b.Cursor = 'Hand'
    $b.TabStop = $false
    return $b
}

function Hover-Rojo($b) {
    $col = $b.ForeColor; $hov = $script:skin.BtnTextoHover
    $b.Add_MouseEnter({ $this.ForeColor = $hov }.GetNewClosure())
    $b.Add_MouseLeave({ $this.ForeColor = $col }.GetNewClosure())
}

function Lanzar($item) {
    $k = $script:skin
    $linea = Azar $k.PorApp[$item.Nombre]
    if (-not $linea) { $linea = Azar $k.Frases }
    try {
        Start-Process $item.Abrir -ErrorAction Stop
        switch ($k.Estilo) {
            'hacker' { Glitch 3 $linea }
            'tele' { Corte-Senal 4; Decir $linea }
            default { Decir $linea }
        }
    } catch {
        if ($item.Web) {
            Start-Process $item.Web
            switch ($k.Estilo) {
                'hacker' { Decir "> $($item.Nombre) not found. redirecting to web..." }
                'tele' { Decir "¡No tengo $($item.Nombre) en la tele! ¡Te pongo la versión web!" }
                default { Decir "$($item.Nombre) no está instalado. Te abro la web. De nada." }
            }
        } else {
            switch ($k.Estilo) {
                'hacker' { Glitch 6 "> ERROR: $($item.Nombre) resisted the hack" }
                'tele' { Corte-Senal 10; Decir "¡Bzzzt! No encuentro el canal $($item.Nombre)..." }
                default { Decir "No encuentro $($item.Nombre). Igual nunca existió." }
            }
        }
    }
}

function Mostrar-Pagina {
    $grid.Controls.Clear()
    $script:bi = 0
    $hacker = $script:skin.Estilo -eq 'hacker'
    if ($script:modoSkins) {
        $i = 0
        foreach ($n in $Skins.Keys) {
            $txt = if ($n -eq $script:skinNombre) { "[ $n ]" } else { $n }
            $b = Nuevo-Boton $txt (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
            $b.Tag = $n
            $b.Add_Click({ Aplicar-Skin $this.Tag })
            if ($hacker) { Hover-Rojo $b }
            $grid.Controls.Add($b); $i++
        }
        $script:lblPag.Text = 'Skins'
        return
    }
    $inicio = $script:pagina * $PorPagina
    $fin = [Math]::Min($inicio + $PorPagina, $Botones.Count) - 1
    $i = 0
    foreach ($item in $Botones[$inicio..$fin]) {
        $b = Nuevo-Boton $item.Nombre (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
        $b.Tag = $item
        $b.Add_Click({ Lanzar $this.Tag })
        if ($hacker) { Hover-Rojo $b }
        $grid.Controls.Add($b); $i++
    }
    $script:lblPag.Text = "Page $($script:pagina + 1)/$totalPaginas"
}

function Efecto-Entrada($prev) {
    $msg = Mensaje-Entrada $prev
    switch ($script:skin.Estilo) {
        'hacker' { Glitch 10 $msg }
        'web' { Transicion-Web $msg }
        'tele' { Transicion-Estatica $msg }
    }
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
    $k = $script:skin; $g = $_.Graphics; $W = $form.ClientSize.Width; $H = $form.ClientSize.Height
    switch ($k.Estilo) {
        'web' {
            $g.SmoothingMode = 'AntiAlias'
            $rect = New-Object System.Drawing.Rectangle(0, 0, $W, 52)
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $k.Barra1, $k.Barra2, 90)
            $g.FillRectangle($br, $rect); $br.Dispose()
            # icono "i" amarillo, como el de la camiseta de SeaDrive
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 198 26))), 12, 11, 30, 30)
            $g.DrawEllipse((New-Object System.Drawing.Pen((C 20 20 20), 2)), 12, 11, 30, 30)
            $g.DrawString('i', (New-Object System.Drawing.Font('Georgia', 15, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 20, 12)
            # franja verde
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 140 220 60))), 0, 52, $W, 4)
            # barra del navegador
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 244 246 249))), 0, 56, $W, 32)
            $g.DrawLine((New-Object System.Drawing.Pen((C 200 205 212), 1)), 0, 88, $W, 88)
            $g.DrawString('◀   ▶   ⟳', (New-Object System.Drawing.Font('Segoe UI Symbol', 10)), (New-Object System.Drawing.SolidBrush((C 90 100 115))), 10, 61)
            $g.FillRectangle([System.Drawing.Brushes]::White, 96, 60, ($W - 112), 24)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 185 195 205), 1)), 96, 60, ($W - 112), 24)
            # franja tipo falda abajo
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, $H - 10, $W, 10)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, $H - 7, $W, 2)
        }
        'tele' {
            $g.SmoothingMode = 'AntiAlias'
            # lunares estilo dibujo animado
            $lun = New-Object System.Drawing.SolidBrush((C 255 95 70))
            for ($y = 64; $y -lt $H; $y += 22) { for ($x = (($y / 22) % 2) * 11; $x -lt $W; $x += 22) { $g.FillEllipse($lun, $x, $y, 7, 7) } }
            $lun.Dispose()
            # barra de título azul (chaqueta de Miku) con línea amarilla (lazo)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 58 44 190))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 225 50))), 0, 52, $W, 5)
            $g.DrawString($k.Titulo, (New-Object System.Drawing.Font($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 15, 9)
            # la tele
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
            $g.DrawString('CH 03', (New-Object System.Drawing.Font('Comic Sans MS', 8, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 548, 213)
            $pen.Dispose()
            # falda de colores abajo
            $arco = @((C 255 40 40), (C 255 150 30), (C 255 225 50), (C 90 210 80), (C 90 220 245), (C 58 44 190), (C 230 80 200))
            $bw = [Math]::Ceiling($W / $arco.Count)
            for ($i = 0; $i -lt $arco.Count; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($arco[$i])), ($i * $bw), ($H - 10), $bw, 10) }
        }
        default {
            # líneas de escaneo tipo monitor viejo
            $scan = New-Object System.Drawing.Pen((C 28 0 0), 1)
            for ($y = 54; $y -lt $H; $y += 4) { $g.DrawLine($scan, 2, $y, $W - 2, $y) }
            $scan.Dispose()
            $g.DrawString($k.Titulo, (New-Object System.Drawing.Font($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($k.Sombra)), 15, 10)
            $pen2 = New-Object System.Drawing.Pen($k.Borde, 2)
            $g.DrawLine($pen2, 0, 52, $W, 52); $pen2.Dispose()
        }
    }
    if ($script:glitching) {
        # rasgaduras de pantalla
        for ($i = 0; $i -lt 6; $i++) {
            $col = @((C 255 0 0), (C 255 255 255), (C 0 255 255), (C 80 0 0))[$Rnd.Next(4)]
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($col)), $Rnd.Next(-50, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 300), $Rnd.Next(1, 7))
        }
    }
    $ancho = if ($k.Estilo -eq 'tele') { 4 } else { 3 }
    $pen = New-Object System.Drawing.Pen($k.Borde, $ancho)
    $g.DrawRectangle($pen, 1, 1, $W - 3, $H - 3); $pen.Dispose()
})

$script:drag = $false
$mDown = { $script:drag = $true; $script:p0 = [System.Windows.Forms.Cursor]::Position; $script:f0 = $form.Location }
$mMove = {
    if ($script:drag -and -not $script:glitching) {
        $p = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($script:f0.X + $p.X - $script:p0.X), ($script:f0.Y + $p.Y - $script:p0.Y))
    }
}
$mUp = { $script:drag = $false }
$form.Add_MouseDown($mDown); $form.Add_MouseMove($mMove); $form.Add_MouseUp($mUp)

function Cargar-Img($rel) {
    if (-not $rel) { return $null }
    $ruta = Join-Path $Raiz $rel
    if (Test-Path $ruta) { return [System.Drawing.Image]::FromFile($ruta) }
    return $null
}

function Construir-UI {
    $k = $Skins[$script:skinNombre]; $script:skin = $k
    # quitar los GIFs de la ventana antes de liberarlos (evita la ventana de error al cambiar de skin)
    $caraTimer.Stop(); $tvTimer.Stop()
    if ($script:pb) { $script:pb.Image = $null; $form.Controls.Remove($script:pb); $script:pb.Dispose(); $script:pb = $null }
    foreach ($im in @($script:imgs.Values)) { if ($im) { $im.Dispose() } }
    $script:imgs = @{}
    if ($script:tvRuido) { $script:tvRuido.Dispose(); $script:tvRuido = $null }
    $script:urlLbl = $null
    $form.Controls.Clear()

    $T = $k.Top
    $conGif = [bool]$k.Gif
    $W = if ($conGif) { 616 } else { 408 }
    $form.Size = New-Object System.Drawing.Size($W, (312 + $T))
    $form.BackColor = $k.Fondo
    $form.Opacity = $k.Opacidad
    $form.Text = $script:skinNombre

    $xTit = if ($k.Estilo -eq 'web') { 48 } else { 12 }
    $titulo = New-Object System.Windows.Forms.Label
    $titulo.Text = $k.Titulo
    $titulo.Font = New-Object System.Drawing.Font($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)
    $titulo.ForeColor = $k.TituloColor
    $titulo.BackColor = [System.Drawing.Color]::Transparent
    $titulo.AutoSize = $true
    $titulo.Location = New-Object System.Drawing.Point($xTit, 6)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $k.Sub
    $sub.Font = New-Object System.Drawing.Font($k.Fuente, 8, [System.Drawing.FontStyle]::Bold)
    $sub.ForeColor = $k.SubColor
    $sub.BackColor = [System.Drawing.Color]::Transparent
    $sub.AutoSize = $true
    $form.Controls.AddRange(@($titulo, $sub))
    $sub.Location = New-Object System.Drawing.Point(($xTit + $titulo.PreferredWidth + 2), 26)
    foreach ($c in @($titulo, $sub)) { $c.Add_MouseDown($mDown); $c.Add_MouseMove($mMove); $c.Add_MouseUp($mUp) }

    $script:bi = 0
    $bCerrar = Nuevo-Boton 'X' ($W - 40) 12 28 28; $bCerrar.ForeColor = $k.BarraBtnTexto
    $bCerrar.Add_Click({ $form.Close() })
    $bMin = Nuevo-Boton '_' ($W - 74) 12 28 28; $bMin.ForeColor = $k.BarraBtnTexto
    $bMin.Add_Click({ $form.WindowState = 'Minimized' })
    $bSkins = Nuevo-Boton 'Skins' ($W - 150) 12 70 28; $bSkins.ForeColor = $k.BarraBtnTexto
    $bSkins.Add_Click({ if (-not (Ocupado)) { $script:modoSkins = -not $script:modoSkins; Mostrar-Pagina } })

    $script:grid = New-Object System.Windows.Forms.Panel
    $grid.Location = New-Object System.Drawing.Point(16, (66 + $T))
    $grid.Size = New-Object System.Drawing.Size(376, 168)
    $grid.BackColor = [System.Drawing.Color]::Transparent

    $script:lblPag = New-Object System.Windows.Forms.Label
    $lblPag.ForeColor = $k.StatusColor
    $lblPag.BackColor = [System.Drawing.Color]::Transparent
    $lblPag.Font = New-Object System.Drawing.Font($k.Fuente, 10, [System.Drawing.FontStyle]::Bold)
    $lblPag.TextAlign = 'MiddleCenter'
    $lblPag.Location = New-Object System.Drawing.Point(140, (242 + $T))
    $lblPag.Size = New-Object System.Drawing.Size(128, 28)
    if ($k.Estilo -eq 'web') { $lblPag.ForeColor = (C 30 30 30) }

    $bAnt = Nuevo-Boton '<' 16 (242 + $T) 120 28
    $bAnt.Add_Click({ if ($script:pagina -gt 0) { $script:modoSkins = $false; $script:pagina--; Mostrar-Pagina } })
    $bSig = Nuevo-Boton '>' 272 (242 + $T) 120 28
    $bSig.Add_Click({ if ($script:pagina -lt $totalPaginas - 1) { $script:modoSkins = $false; $script:pagina++; Mostrar-Pagina } })

    $script:status = New-Object System.Windows.Forms.Label
    $status.ForeColor = $k.StatusColor
    $form.Controls.AddRange(@($bSkins, $bMin, $bCerrar, $grid, $bAnt, $lblPag, $bSig, $status))
    if ($k.Estilo -eq 'hacker') { foreach ($b in @($bSkins, $bMin, $bCerrar, $bAnt, $bSig)) { Hover-Rojo $b } }

    if ($k.Estilo -eq 'web') {
        # barra de direcciones del "navegador"
        $candado = New-Object System.Windows.Forms.Label
        $candado.Text = '🔒'
        $candado.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 9)
        $candado.ForeColor = (C 30 140 60)
        $candado.BackColor = [System.Drawing.Color]::White
        $candado.Location = New-Object System.Drawing.Point(100, 63)
        $candado.Size = New-Object System.Drawing.Size(20, 19)
        $script:urlLbl = New-Object System.Windows.Forms.Label
        $urlLbl.Text = $k.Url
        $urlLbl.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $urlLbl.ForeColor = (C 40 40 40)
        $urlLbl.BackColor = [System.Drawing.Color]::White
        $urlLbl.Location = New-Object System.Drawing.Point(121, 64)
        $urlLbl.Size = New-Object System.Drawing.Size(($W - 142), 18)
        $form.Controls.AddRange(@($candado, $urlLbl))
    }

    if ($conGif) {
        $script:imgs = @{ main = (Cargar-Img $k.Gif); clic = (Cargar-Img $k.GifClic); raro = (Cargar-Img $k.GifRaro) }
        $script:pb = New-Object System.Windows.Forms.PictureBox
        $pb.SizeMode = 'Zoom'
        $pb.Cursor = 'Hand'
        $pb.Image = $script:imgs.main
        $pb.Add_Click({
            $k = $script:skin
            if ($k.Estilo -eq 'tele') { Cara 'clic' 3000 }
            Decir (Azar $k.Clic)
        })

        $status.BackColor = [System.Drawing.Color]::White
        $status.BorderStyle = 'FixedSingle'
        $status.Padding = New-Object System.Windows.Forms.Padding(4)
        $status.ForeColor = (C 20 20 20)

        if ($k.Estilo -eq 'tele') {
            # pantalla de la tele
            $pb.Location = New-Object System.Drawing.Point(414, 76)
            $pb.Size = New-Object System.Drawing.Size(182, 132)
            $pb.BackColor = [System.Drawing.Color]::Black
            $script:tvRuido = Nuevo-Ruido 64 48
            $status.Font = New-Object System.Drawing.Font($k.Fuente, 9, [System.Drawing.FontStyle]::Bold)
            $status.Location = New-Object System.Drawing.Point(404, 240)
            $status.Size = New-Object System.Drawing.Size(202, 56)
        } else {
            $pb.Location = New-Object System.Drawing.Point(410, (66 + $T))
            $pb.Size = New-Object System.Drawing.Size(190, 150)
            $pb.BackColor = [System.Drawing.Color]::White
            $pb.BorderStyle = 'FixedSingle'
            $status.Font = New-Object System.Drawing.Font($k.Fuente, 9, [System.Drawing.FontStyle]::Bold)
            $status.Location = New-Object System.Drawing.Point(410, (222 + $T))
            $status.Size = New-Object System.Drawing.Size(190, 70)
        }
        $form.Controls.Add($pb)
    } else {
        $status.BackColor = [System.Drawing.Color]::Black
        $status.Font = New-Object System.Drawing.Font('Consolas', 8.5)
        $status.Location = New-Object System.Drawing.Point(14, (278 + $T))
        $status.Size = New-Object System.Drawing.Size(380, 22)
    }

    Mostrar-Pagina
    $script:twTexto = ''; $script:twPos = 0; $status.Text = ''
    $form.Invalidate()
}

Construir-UI
$form.Add_Shown({
    $twTimer.Start(); $idleTimer.Start()
    Efecto-Entrada $null
})
[void]$form.ShowDialog()
