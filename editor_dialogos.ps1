# ================================================================
#  EDITOR DE DIÁLOGOS de c00lgui
#  Abre los archivos de la carpeta "dialogos" (uno por skin + _charlas.json) y deja verlos y cambiarlos
#  por apartados. Se abre con editor_dialogos.vbs (doble clic) y no necesita que el panel esté abierto.
#  Lee del código (sin ejecutarlo) la lista de skins y sus grupos, y del lore el estado y la ficha de cada una.
# ================================================================
param($Prueba)   # solo para las pruebas automáticas: un script que se carga antes de abrir la ventana
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try {
    Add-Type -Namespace C00lEd -Name Dpi -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][C00lEd.Dpi]::SetProcessDPIAware()
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

$Raiz = $PSScriptRoot
$CarpetaDialogos = Join-Path $Raiz 'dialogos'
$CarpetaLore = Join-Path $Raiz 'lore'
$gDpi = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $K = $gDpi.DpiX / 96.0; $gDpi.Dispose()
function P($n) { [int]($n * $K) }
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

# nombres que se ven en la pestaña Frases (el resto de campos que no son fijos van a Mecánica)
$NombresFrases = [ordered]@{ Hola = 'Al aparecer (entrada)'; Frases = 'Al abrir una app'; Idle = 'Frases sueltas (cuando está quieta)'; Clic = 'Al hacerle clic'; Yo = 'Su botón en el menú Skins' }
$CamposFijos = @('Hola', 'Yo', 'Frases', 'Idle', 'Clic', 'PorApp', 'AlVenirDe', 'Opina')
$LargoMax = 220     # frases más largas que esto salen en los avisos (no caben bien en el bocadillo)
$CharlasMin = 5     # cada skin debería salir en al menos 5 charlas

# ---------------------------------------------------------------- DATOS
# lista de skins (en orden) y grupos del menú Skins, leídos del código sin ejecutarlo
function Leer-Skins {
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Raiz 'c00lgui.ps1'), [ref]$tok, [ref]$err)
    $esTabla = { param($a) $a -is [System.Management.Automation.Language.HashtableAst] }
    $asig = @($ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.AssignmentStatementAst] }, $false))
    $aSkins = $asig | Where-Object { $_.Left.Extent.Text -eq '$Skins' } | Select-Object -First 1
    $aGrupos = $asig | Where-Object { $_.Left.Extent.Text -eq '$GruposSkins' } | Select-Object -First 1
    $script:orden = @(foreach ($kv in $aSkins.Right.Find($esTabla, $true).KeyValuePairs) { $kv.Item1.Value })
    $script:grupos = [ordered]@{}
    foreach ($kv in $aGrupos.Right.Find($esTabla, $true).KeyValuePairs) {
        $l = [ordered]@{}
        foreach ($p in $kv.Item2.Find($esTabla, $true).KeyValuePairs) {
            $l[$p.Item1.Value] = $p.Item2.Find({ param($a) $a -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true).Value
        }
        $script:grupos[$kv.Item1.Value] = $l
    }
    # las skins archivadas (archivadas.txt) van a su propio grupo, al final
    $script:archivadas = @()
    $fa = Join-Path $Raiz 'archivadas.txt'
    if (Test-Path -LiteralPath $fa) { foreach ($l in [IO.File]::ReadAllLines($fa, [Text.Encoding]::UTF8)) { $n = $l.Trim(); if ($n -and -not $n.StartsWith('#') -and $script:orden -contains $n) { $script:archivadas += $n } } }
    foreach ($g in @($script:grupos.Keys)) { foreach ($n in $script:archivadas) { if ($script:grupos[$g].Contains($n)) { $script:grupos[$g].Remove($n) } } }
    # las skins que no estén en ningún grupo van a "Otras"
    $sueltas = @($script:orden | Where-Object { $n = $_; ($script:archivadas -notcontains $n) -and -not @($script:grupos.Values | Where-Object { $_.Contains($n) }) })
    if ($sueltas.Count) { $l = [ordered]@{}; foreach ($s in $sueltas) { $l[$s] = '' }; $script:grupos['Otras'] = $l }
    if ($script:archivadas.Count) { $l = [ordered]@{}; foreach ($s in $script:archivadas) { $l[$s] = '' }; $script:grupos['Archivadas'] = $l }
}
# estado de cada skin (lore\estado.md): bien / revisar / sin revisar
function Leer-Estado {
    $script:estado = @{}
    $f = Join-Path $CarpetaLore 'estado.md'
    if (-not (Test-Path -LiteralPath $f)) { return }
    foreach ($l in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) {
        if ($l -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|') {
            $nom = $Matches[1]; $e = $Matches[2]
            $script:estado[$nom] = $(if ($e -match 'Sin revisar') { 'sin' } elseif ($e -match 'Revisar') { 'revisar' } elseif ($e -match 'Bien') { 'bien' } else { 'sin' })
        }
    }
}
# lo que lee ConvertFrom-Json se pasa a tablas ordenadas y listas (ArrayList) de textos
function A-Modelo($o) {
    if ($null -eq $o -or $o -is [string]) { return $o }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $d = [ordered]@{}; foreach ($p in $o.PSObject.Properties) { $d[$p.Name] = A-Modelo $p.Value }; return $d
    }
    if ($o -is [array]) { $l = New-Object System.Collections.ArrayList; foreach ($x in $o) { [void]$l.Add((A-Modelo $x)) }; return , $l }
    return [string]$o
}
function Leer-Json($f) { [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json }
function Cargar-Skin($n) {
    $f = Join-Path $CarpetaDialogos "$n.json"
    $script:datos[$n] = $(if (Test-Path -LiteralPath $f) { A-Modelo (Leer-Json $f) } else { [ordered]@{} })
}
function Cargar-Charlas {
    $f = Join-Path $CarpetaDialogos '_charlas.json'
    $script:charlas = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $f) { $j = Leer-Json $f; $c = A-Modelo $j.charlas; if ($c -is [System.Collections.ArrayList]) { $script:charlas = $c } }
}
# --- guardar en el mismo formato que los archivos (fácil de leer: una frase por línea) ---
function JS($s) {
    $t = ([string]$s).Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
    return '"' + $t + '"'
}
function Lista-En-Linea($l) { '[' + ((@($l) | ForEach-Object { JS $_ }) -join ', ') + ']' }
function Guardar-Skin($n) {
    $d = $script:datos[$n]; $partes = New-Object System.Collections.ArrayList
    foreach ($k in @($d.Keys)) {
        $v = $d[$k]
        if ($v -is [string]) { $txt = JS $v }
        elseif ($v -is [System.Collections.Specialized.OrderedDictionary]) {
            $claves = @($script:orden | Where-Object { $v.Contains($_) }) + @($v.Keys | Where-Object { $script:orden -notcontains $_ })
            $filas = foreach ($c in $claves) { $x = $v[$c]; '    ' + (JS $c) + ': ' + $(if ($x -is [string]) { JS $x } else { Lista-En-Linea $x }) }
            $txt = $(if (@($filas).Count) { "{`r`n" + (@($filas) -join ",`r`n") + "`r`n  }" } else { '{}' })
        } else {
            $txt = $(if (@($v).Count -eq 0) { '[]' } else { "[`r`n" + ((@($v) | ForEach-Object { '    ' + (JS $_) }) -join ",`r`n") + "`r`n  ]" })
        }
        [void]$partes.Add('  ' + (JS $k) + ': ' + $txt)
    }
    $json = "{`r`n" + ($partes -join ",`r`n") + "`r`n}`r`n"
    [IO.File]::WriteAllText((Join-Path $CarpetaDialogos "$n.json"), $json, (New-Object Text.UTF8Encoding $false))
}
function Guardar-Charlas {
    $bloques = foreach ($ch in $script:charlas) {
        $lin = @($ch | Where-Object { ([string]$_[1]).Trim() -ne '' })
        if ($lin.Count -eq 0) { continue }
        "    [`r`n" + ((@($lin) | ForEach-Object { '      ' + (Lista-En-Linea @($_[0], $_[1])) }) -join ",`r`n") + "`r`n    ]"
    }
    $json = "{`r`n  `"charlas`": [`r`n" + (@($bloques) -join ",`r`n") + "`r`n  ]`r`n}`r`n"
    [IO.File]::WriteAllText((Join-Path $CarpetaDialogos '_charlas.json'), $json, (New-Object Text.UTF8Encoding $false))
}
function Participantes($ch) { @($ch | ForEach-Object { $_[0] } | Select-Object -Unique) }
function Invitado-De($ch, $n) { $o = @(Participantes $ch | Where-Object { $_ -ne $n }); if ($o.Count) { $o[0] } else { '' } }

# ---------------------------------------------------------------- VENTANA
$fuente = New-Object System.Drawing.Font('Segoe UI', 10)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Editor de diálogos – c00lgui'; $form.Size = New-Object System.Drawing.Size((P 1180), (P 760))
$form.StartPosition = 'CenterScreen'; $form.Font = $fuente; $form.BackColor = (C 246 244 250)
$form.MinimumSize = New-Object System.Drawing.Size((P 900), (P 560))

$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = 'Fill'; $split.FixedPanel = 'Panel1'; $split.SplitterWidth = (P 6)
$form.Controls.Add($split)

# --- izquierda: personajes por grupos ---
$tituloIzq = New-Object System.Windows.Forms.Label
$tituloIzq.Text = 'PERSONAJES'; $tituloIzq.Dock = 'Top'; $tituloIzq.Height = (P 30); $tituloIzq.TextAlign = 'MiddleLeft'
$tituloIzq.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold); $tituloIzq.Padding = New-Object System.Windows.Forms.Padding((P 6), 0, 0, 0)
$leyenda = New-Object System.Windows.Forms.Label
$leyenda.Text = "● bien    ● revisar    ● sin revisar"; $leyenda.Dock = 'Bottom'; $leyenda.Height = (P 26); $leyenda.TextAlign = 'MiddleCenter'
$leyenda.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$arbol = New-Object System.Windows.Forms.TreeView
$arbol.Dock = 'Fill'; $arbol.HideSelection = $false; $arbol.FullRowSelect = $true; $arbol.ShowLines = $false; $arbol.ItemHeight = (P 24)
$arbol.BorderStyle = 'None'; $arbol.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$split.Panel1.Controls.Add($arbol); $split.Panel1.Controls.Add($tituloIzq); $split.Panel1.Controls.Add($leyenda)
$split.Panel1.BackColor = [System.Drawing.Color]::White

# --- derecha: cabecera, pestañas y avisos ---
$cab = New-Object System.Windows.Forms.Panel
$cab.Dock = 'Top'; $cab.Height = (P 56); $cab.Padding = New-Object System.Windows.Forms.Padding((P 10), (P 8), (P 10), (P 6))
$lbNombre = New-Object System.Windows.Forms.Label
$lbNombre.Dock = 'Fill'; $lbNombre.TextAlign = 'MiddleLeft'; $lbNombre.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$botones = New-Object System.Windows.Forms.FlowLayoutPanel
$botones.Dock = 'Right'; $botones.Width = (P 260); $botones.FlowDirection = 'RightToLeft'; $botones.WrapContents = $false
function Nuevo-Boton($txt, $ancho) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $txt; $b.Width = (P $ancho); $b.Height = (P 34); $b.FlatStyle = 'System'
    return $b
}
$btGuardar = Nuevo-Boton 'Guardar' 110; $btGuardar.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$btDeshacer = Nuevo-Boton 'Deshacer cambios' 140
$botones.Controls.Add($btGuardar); $botones.Controls.Add($btDeshacer)
$cab.Controls.Add($lbNombre); $cab.Controls.Add($botones)

$avisos = New-Object System.Windows.Forms.TextBox
$avisos.Dock = 'Bottom'; $avisos.Height = (P 70); $avisos.Multiline = $true; $avisos.ReadOnly = $true; $avisos.ScrollBars = 'Vertical'
$avisos.BackColor = (C 255 248 230); $avisos.ForeColor = (C 150 80 0); $avisos.BorderStyle = 'FixedSingle'

$pestanas = New-Object System.Windows.Forms.TabControl
$pestanas.Dock = 'Fill'; $pestanas.Padding = New-Object System.Drawing.Point((P 12), (P 5))
$split.Panel2.Controls.Add($pestanas); $split.Panel2.Controls.Add($cab); $split.Panel2.Controls.Add($avisos)
$pestanas.BringToFront()

function Nueva-Pestana($titulo) { $t = New-Object System.Windows.Forms.TabPage; $t.Text = $titulo; $t.Padding = New-Object System.Windows.Forms.Padding((P 6)); $t.BackColor = [System.Drawing.Color]::White; [void]$pestanas.TabPages.Add($t); return $t }
function Nueva-Rejilla {
    $dg = New-Object System.Windows.Forms.DataGridView
    $dg.Dock = 'Fill'; $dg.AllowUserToAddRows = $true; $dg.AllowUserToDeleteRows = $true; $dg.AllowUserToResizeRows = $false
    $dg.RowHeadersWidth = (P 30); $dg.AutoSizeRowsMode = 'AllCells'; $dg.AutoSizeColumnsMode = 'Fill'
    $dg.DefaultCellStyle.WrapMode = 'True'; $dg.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(2, 3, 2, 3)
    $dg.BackgroundColor = [System.Drawing.Color]::White; $dg.BorderStyle = 'None'; $dg.ColumnHeadersHeightSizeMode = 'AutoSize'
    $dg.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $dg.EnableHeadersVisualStyles = $true; $dg.GridColor = (C 225 222 232)
    $dg.Add_CellValueChanged({ Marcar-Sucio $this })
    $dg.Add_UserDeletedRow({ Marcar-Sucio $this })
    $dg.Add_DataError({ $_.ThrowException = $false })
    return $dg
}
function Columna($dg, $titulo, $peso, $soloLeer) {
    $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $c.HeaderText = $titulo; $c.FillWeight = $peso; $c.SortMode = 'NotSortable'
    if ($soloLeer) { $c.ReadOnly = $true; $c.DefaultCellStyle.BackColor = (C 243 240 250); $c.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold) }
    [void]$dg.Columns.Add($c); return $c
}
function Ayuda($txt) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $txt; $l.Dock = 'Top'; $l.Height = (P 26); $l.ForeColor = (C 110 100 130); $l.TextAlign = 'MiddleLeft'
    return $l
}
# lista a la izquierda + rejilla de frases a la derecha (pestañas Frases y Mecánica)
function Lista-Y-Rejilla($pagina, $textoAyuda) {
    $sp = New-Object System.Windows.Forms.SplitContainer
    $sp.Dock = 'Fill'; $sp.FixedPanel = 'Panel1'
    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Dock = 'Fill'; $lb.IntegralHeight = $false; $lb.BorderStyle = 'None'; $lb.ItemHeight = (P 24); $lb.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $sp.Panel1.Controls.Add($lb)
    $dg = Nueva-Rejilla; [void](Columna $dg 'Frase (una por fila; la fila vacía de abajo sirve para añadir; para borrar, selecciona la fila a la izquierda y pulsa Supr)' 100 $false)
    $sp.Panel2.Controls.Add($dg); $sp.Panel2.Controls.Add((Ayuda $textoAyuda))
    $dg.BringToFront()
    $pagina.Controls.Add($sp)
    return @{ Split = $sp; Lista = $lb; Rejilla = $dg; Claves = @(); Clave = $null }
}

# 1) Ficha
$pFicha = Nueva-Pestana 'Ficha'
$txFicha = New-Object System.Windows.Forms.TextBox
$txFicha.Dock = 'Fill'; $txFicha.Multiline = $true; $txFicha.ReadOnly = $true; $txFicha.ScrollBars = 'Vertical'; $txFicha.WordWrap = $true
$txFicha.BackColor = [System.Drawing.Color]::White; $txFicha.BorderStyle = 'None'; $txFicha.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
$pFicha.Controls.Add($txFicha); $pFicha.Controls.Add((Ayuda 'Cómo es el personaje (lore\personajes). Léela antes de escribir: cada frase tiene que sonar a él/ella.'))
$txFicha.BringToFront()
# 2) Frases
$pFrases = Nueva-Pestana 'Frases'
$frases = Lista-Y-Rejilla $pFrases 'Elige a la izquierda qué frases quieres ver. Cada fila es una frase.'
# 3) Apps
$pApps = Nueva-Pestana 'Apps'
$dgApps = Nueva-Rejilla
$pApps.Controls.Add($dgApps); $pApps.Controls.Add((Ayuda 'Lo que dice al abrir cada botón. Puedes añadir un botón nuevo en la última fila (con el nombre exacto del botón).'))
$dgApps.BringToFront()
# 4) Otras skins
$pOtras = Nueva-Pestana 'Otras skins'
$dgOtras = Nueva-Rejilla; $dgOtras.AllowUserToAddRows = $false; $dgOtras.AllowUserToDeleteRows = $false
$pOtras.Controls.Add($dgOtras); $pOtras.Controls.Add((Ayuda '"Al venir de": lo que dice al sustituir a esa skin. "Opina": lo que piensa de ella (sale al pasar el ratón por el menú Skins).'))
$dgOtras.BringToFront()
# 5) Charlas
$pCharlas = Nueva-Pestana 'Charlas'
$spCh = New-Object System.Windows.Forms.SplitContainer; $spCh.Dock = 'Fill'; $spCh.FixedPanel = 'Panel1'
$lbCharlas = New-Object System.Windows.Forms.ListBox
$lbCharlas.Dock = 'Fill'; $lbCharlas.IntegralHeight = $false; $lbCharlas.BorderStyle = 'None'; $lbCharlas.ItemHeight = (P 24); $lbCharlas.HorizontalScrollbar = $true
$lbCuantas = Ayuda ''; $lbCuantas.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$chBotones = New-Object System.Windows.Forms.FlowLayoutPanel; $chBotones.Dock = 'Bottom'; $chBotones.Height = (P 42)
$btNuevaCh = Nuevo-Boton '+ Nueva charla' 130; $btBorrarCh = Nuevo-Boton 'Borrar charla' 120
$chBotones.Controls.Add($btNuevaCh); $chBotones.Controls.Add($btBorrarCh)
$spCh.Panel1.Controls.Add($lbCharlas); $spCh.Panel1.Controls.Add($lbCuantas); $spCh.Panel1.Controls.Add($chBotones); $lbCharlas.BringToFront()
$chArriba = New-Object System.Windows.Forms.FlowLayoutPanel; $chArriba.Dock = 'Top'; $chArriba.Height = (P 40); $chArriba.WrapContents = $false
$lbInv = New-Object System.Windows.Forms.Label; $lbInv.Text = 'Invitado:'; $lbInv.AutoSize = $true; $lbInv.Margin = New-Object System.Windows.Forms.Padding(3, (P 9), 3, 3)
$cbInvitado = New-Object System.Windows.Forms.ComboBox; $cbInvitado.DropDownStyle = 'DropDownList'; $cbInvitado.Width = (P 220)
$lbInvAyuda = New-Object System.Windows.Forms.Label; $lbInvAyuda.AutoSize = $true; $lbInvAyuda.ForeColor = (C 110 100 130); $lbInvAyuda.Margin = New-Object System.Windows.Forms.Padding((P 12), (P 9), 3, 3)
$lbInvAyuda.Text = 'Cada fila es una línea de la charla, en orden. Sale igual con las dos skins.'
$chArriba.Controls.Add($lbInv); $chArriba.Controls.Add($cbInvitado); $chArriba.Controls.Add($lbInvAyuda)
$dgCharla = Nueva-Rejilla
$colQuien = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
$colQuien.HeaderText = 'Quién'; $colQuien.FillWeight = 22; $colQuien.FlatStyle = 'Flat'; $colQuien.DisplayStyle = 'DropDownButton'
[void]$dgCharla.Columns.Add($colQuien)
[void](Columna $dgCharla 'Qué dice' 78 $false)
$spCh.Panel2.Controls.Add($dgCharla); $spCh.Panel2.Controls.Add($chArriba); $dgCharla.BringToFront()
$pCharlas.Controls.Add($spCh)
# 6) Mecánica
$pMeca = Nueva-Pestana 'Mecánica'
$meca = Lista-Y-Rejilla $pMeca 'Frases de su mecánica (por ejemplo, cuando gana, pierde o se enfada). Solo las tienen algunas skins.'

# ---------------------------------------------------------------- ESTADO DE LA EDICIÓN
$script:datos = @{}; $script:actual = $null; $script:cargando = $false
$script:sucio = @{}; $script:charlasSucias = $false
$script:idxCharlas = @(); $script:charlaActual = -1; $script:invitadoActual = ''
function Marcar-Sucio($quien) {
    if ($script:cargando -or -not $script:actual) { return }
    if ($quien -eq $dgCharla -or $quien -eq 'charlas') { $script:charlasSucias = $true } else { $script:sucio[$script:actual] = $true }
    Poner-Titulo
}
function Hay-Cambios { return ($script:charlasSucias -or @($script:sucio.Keys | Where-Object { $script:sucio[$_] }).Count -gt 0) }
function Poner-Titulo { $form.Text = 'Editor de diálogos – c00lgui' + $(if (Hay-Cambios) { '   (sin guardar)' } else { '' }) }
function Filas-A-Lista($dg, $col) {
    $l = New-Object System.Collections.ArrayList
    foreach ($r in $dg.Rows) { if ($r.IsNewRow) { continue }; $v = [string]$r.Cells[$col].Value; if ($v.Trim() -ne '') { [void]$l.Add($v.Trim()) } }
    return , $l
}
# --- de la pantalla a los datos (se llama antes de cambiar de skin, de apartado o de guardar) ---
function Volcar-Lista($lr) {
    if (-not $script:actual -or -not $lr.Clave) { return }
    $dg = $lr.Rejilla; if ($dg.IsCurrentCellInEditMode) { [void]$dg.EndEdit() }
    $script:datos[$script:actual][$lr.Clave] = Filas-A-Lista $dg 0
}
function Volcar-Apps {
    if (-not $script:actual) { return }
    if ($dgApps.IsCurrentCellInEditMode) { [void]$dgApps.EndEdit() }
    $t = [ordered]@{}
    foreach ($r in $dgApps.Rows) {
        if ($r.IsNewRow) { continue }
        $app = ([string]$r.Cells[0].Value).Trim(); if ($app -eq '') { continue }
        $l = New-Object System.Collections.ArrayList
        for ($i = 1; $i -lt $dgApps.Columns.Count; $i++) { $v = ([string]$r.Cells[$i].Value).Trim(); if ($v) { [void]$l.Add($v) } }
        if ($l.Count) { $t[$app] = $l }
    }
    $script:datos[$script:actual]['PorApp'] = $t
}
function Volcar-Otras {
    if (-not $script:actual) { return }
    if ($dgOtras.IsCurrentCellInEditMode) { [void]$dgOtras.EndEdit() }
    $d = $script:datos[$script:actual]
    if (-not $d.Contains('AlVenirDe')) { $d['AlVenirDe'] = [ordered]@{} }
    if (-not $d.Contains('Opina')) { $d['Opina'] = [ordered]@{} }
    foreach ($r in $dgOtras.Rows) {
        $s = [string]$r.Cells[0].Value
        $al = ([string]$r.Cells[1].Value).Trim()
        if ($al) { $d['AlVenirDe'][$s] = $al } elseif ($d['AlVenirDe'].Contains($s)) { $d['AlVenirDe'].Remove($s) }
        $l = New-Object System.Collections.ArrayList
        for ($i = 2; $i -lt $dgOtras.Columns.Count; $i++) { $v = ([string]$r.Cells[$i].Value).Trim(); if ($v) { [void]$l.Add($v) } }
        if ($l.Count) { $d['Opina'][$s] = $l } elseif ($d['Opina'].Contains($s)) { $d['Opina'].Remove($s) }
    }
}
function Volcar-Charla {
    if ($script:charlaActual -lt 0) { return }
    if ($dgCharla.IsCurrentCellInEditMode) { [void]$dgCharla.EndEdit() }
    $l = New-Object System.Collections.ArrayList
    foreach ($r in $dgCharla.Rows) {
        if ($r.IsNewRow) { continue }
        $q = [string]$r.Cells[0].Value; $t = [string]$r.Cells[1].Value
        if (-not $q) { $q = $script:actual }
        if ($t.Trim() -ne '') { [void]$l.Add(@($q, $t.Trim())) }
    }
    $script:charlas[$script:charlaActual] = $l
}
function Volcar-Todo { Volcar-Lista $frases; Volcar-Lista $meca; Volcar-Apps; Volcar-Otras; Volcar-Charla }

# --- de los datos a la pantalla ---
function Llenar-Lista($lr, $claves, $nombres) {
    $lr.Lista.Items.Clear(); $lr.Claves = @($claves); $lr.Clave = $null
    $d = $script:datos[$script:actual]
    foreach ($c in $claves) { $n = if ($nombres -and $nombres.Contains($c)) { $nombres[$c] } else { $c }; [void]$lr.Lista.Items.Add("$n  ($(@($d[$c]).Count))") }
    $lr.Rejilla.Rows.Clear()
    if ($lr.Lista.Items.Count) { $lr.Lista.SelectedIndex = 0; Mostrar-Lista $lr }
}
function Mostrar-Lista($lr) {
    $i = $lr.Lista.SelectedIndex; if ($i -lt 0) { return }
    $antes = $script:cargando; $script:cargando = $true
    $lr.Clave = $lr.Claves[$i]; $dg = $lr.Rejilla; $dg.Rows.Clear()
    foreach ($f in @($script:datos[$script:actual][$lr.Clave])) { if ($null -ne $f) { [void]$dg.Rows.Add([string]$f) } }
    $script:cargando = $antes
}
function Rehacer-Columnas($dg, $fijas, $nombre, $n) {
    $dg.Columns.Clear()
    $primera = Columna $dg $fijas[0] 16 $true
    if ($fijas.Count -gt 1) { [void](Columna $dg $fijas[1] 30 $false) }
    for ($i = 1; $i -le $n; $i++) { [void](Columna $dg "$nombre $i" 30 $false) }
}
function Mostrar-Apps {
    $d = $script:datos[$script:actual]; $t = if ($d.Contains('PorApp')) { $d['PorApp'] } else { [ordered]@{} }
    $max = 2; foreach ($k in $t.Keys) { $max = [Math]::Max($max, @($t[$k]).Count) }
    Rehacer-Columnas $dgApps @('Botón') 'Frase' ($max + 1)
    $dgApps.Columns[0].ReadOnly = $false
    foreach ($k in $t.Keys) { $fila = @($k) + @($t[$k]); [void]$dgApps.Rows.Add([object[]]$fila) }
}
function Mostrar-Otras {
    $d = $script:datos[$script:actual]
    $al = if ($d.Contains('AlVenirDe')) { $d['AlVenirDe'] } else { @{} }; $op = if ($d.Contains('Opina')) { $d['Opina'] } else { @{} }
    $max = 2; foreach ($k in $op.Keys) { $max = [Math]::Max($max, @($op[$k]).Count) }
    Rehacer-Columnas $dgOtras @('Skin', 'Al venir de') 'Opina' $max
    foreach ($s in $script:orden) {
        if ($s -eq $script:actual) { continue }
        $fila = @($s, $(if ($al.Contains($s)) { [string]$al[$s] } else { '' })) + @($(if ($op.Contains($s)) { @($op[$s]) } else { @() }))
        while ($fila.Count -lt $dgOtras.Columns.Count) { $fila += '' }
        $i = $dgOtras.Rows.Add([object[]]$fila)
        if (-not $al.Contains($s) -or -not $op.Contains($s)) { $dgOtras.Rows[$i].Cells[0].Style.ForeColor = (C 200 90 0) }
    }
}
function Texto-Charla($ch) {
    $inv = Invitado-De $ch $script:actual
    $prim = if (@($ch).Count) { [string]$ch[0][1] } else { '' }
    if ($prim.Length -gt 46) { $prim = $prim.Substring(0, 46) + '…' }
    return "con $inv  ·  $prim"
}
function Mostrar-Charlas {
    $lbCharlas.Items.Clear(); $script:idxCharlas = @()
    for ($i = 0; $i -lt $script:charlas.Count; $i++) {
        if ((Participantes $script:charlas[$i]) -contains $script:actual) { $script:idxCharlas += $i; [void]$lbCharlas.Items.Add((Texto-Charla $script:charlas[$i])) }
    }
    $n = $script:idxCharlas.Count
    $lbCuantas.Text = "Sale en $n charla$(if ($n -ne 1) { 's' })" + $(if ($n -lt $CharlasMin) { "  (mínimo $CharlasMin)" } else { '' })
    $lbCuantas.ForeColor = $(if ($n -lt $CharlasMin) { (C 200 90 0) } else { (C 40 140 60) })
    $script:charlaActual = -1; $dgCharla.Rows.Clear()
    if ($n) { $lbCharlas.SelectedIndex = 0 } else { $cbInvitado.Enabled = $false }
}
function Mostrar-Charla {
    $i = $lbCharlas.SelectedIndex; if ($i -lt 0) { return }
    $antes = $script:cargando; $script:cargando = $true
    $script:charlaActual = $script:idxCharlas[$i]; $ch = $script:charlas[$script:charlaActual]
    $script:invitadoActual = Invitado-De $ch $script:actual
    $cbInvitado.Enabled = $true; $cbInvitado.SelectedItem = $script:invitadoActual
    $colQuien.Items.Clear(); [void]$colQuien.Items.Add($script:actual); if ($script:invitadoActual) { [void]$colQuien.Items.Add($script:invitadoActual) }
    $dgCharla.Rows.Clear()
    foreach ($par in $ch) { [void]$dgCharla.Rows.Add([string]$par[0], [string]$par[1]) }
    $script:cargando = $antes
}
function Leer-Ficha($n) {
    $f = Join-Path $CarpetaLore "personajes\$n.md"
    if (Test-Path -LiteralPath $f) { return ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) -replace "(?<!`r)`n", "`r`n") }
    $t = "Todavía no hay ficha de $n.`r`n`r`nSe escribirá en lore\personajes\$n.md con:`r`n"
    $t += "  1. Quién es (lore original)`r`n  2. Personalidad (3 a 5 rasgos)`r`n  3. Cómo habla`r`n  4. Cómo trata a los demás`r`n  5. Lo que NUNCA haría o diría`r`n  6. Frases modelo`r`n  7. Fuentes"
    return $t
}
function Calcular-Avisos {
    $n = $script:actual; $d = $script:datos[$n]; $l = New-Object System.Collections.ArrayList
    foreach ($c in @('Hola', 'Frases', 'Idle', 'Clic', 'Yo')) { if (-not $d.Contains($c) -or @($d[$c]).Count -eq 0) { [void]$l.Add("Falta: $($NombresFrases[$c])") } }
    # no hace falta opinar de las archivadas (no salen en el menú), ni que una archivada tenga charlas
    $otras = @($script:orden | Where-Object { $_ -ne $n -and $script:archivadas -notcontains $_ })
    $sinAl = @($otras | Where-Object { -not ($d.Contains('AlVenirDe') -and $d['AlVenirDe'].Contains($_)) })
    $sinOp = @($otras | Where-Object { -not ($d.Contains('Opina') -and $d['Opina'].Contains($_)) })
    if ($sinAl.Count) { [void]$l.Add("Sin 'Al venir de': " + ($sinAl -join ', ')) }
    if ($sinOp.Count) { [void]$l.Add("Sin opinión sobre: " + ($sinOp -join ', ')) }
    if ($script:archivadas -contains $n) { [void]$l.Add('Archivada: no sale en el menú Skins y sus charlas no salen en el panel (se guardan por si vuelve).') }
    else {
        $nch = @($script:charlas | Where-Object { $p = Participantes $_; ($p -contains $n) -and -not @($p | Where-Object { $script:archivadas -contains $_ }).Count }).Count
        if ($nch -lt $CharlasMin) { [void]$l.Add("Sale solo en $nch charlas que se ven (mínimo $CharlasMin; no cuentan las que son con skins archivadas)") }
    }
    $largas = 0
    foreach ($k in $d.Keys) {
        $v = $d[$k]
        $todas = if ($v -is [System.Collections.Specialized.OrderedDictionary]) { foreach ($x in $v.Values) { $x } } else { $v }
        foreach ($f in @($todas)) { if (([string]$f).Length -gt $LargoMax) { $largas++ } }
    }
    if ($largas) { [void]$l.Add("$largas frase$(if ($largas -ne 1) { 's' }) muy larga$(if ($largas -ne 1) { 's' }) (más de $LargoMax letras): puede que no quepa bien en el bocadillo") }
    return $l
}
function Actualizar-Resumen {
    $n = $script:actual; $d = $script:datos[$n]
    $nFr = 0; foreach ($c in $NombresFrases.Keys) { if ($d.Contains($c)) { $nFr += @($d[$c]).Count } }
    $nApps = if ($d.Contains('PorApp')) { $d['PorApp'].Count } else { 0 }
    $otras = $script:orden.Count - 1
    $hechas = @($script:orden | Where-Object { $_ -ne $n -and $d.Contains('Opina') -and $d['Opina'].Contains($_) -and $d.Contains('AlVenirDe') -and $d['AlVenirDe'].Contains($_) }).Count
    $nCh = @($script:charlas | Where-Object { (Participantes $_) -contains $n }).Count
    $mec = @($d.Keys | Where-Object { $CamposFijos -notcontains $_ })
    $pFrases.Text = "Frases ($nFr)"; $pApps.Text = "Apps ($nApps)"; $pOtras.Text = "Otras skins ($hechas/$otras)"
    $pCharlas.Text = "Charlas ($nCh)"; $pMeca.Text = "Mecánica ($($mec.Count))"
    $av = Calcular-Avisos
    $avisos.Text = $(if ($av.Count) { '⚠  ' + ($av -join "`r`n⚠  ") } else { '✓  No falta nada.' })
    $avisos.ForeColor = $(if ($av.Count) { (C 150 80 0) } else { (C 40 140 60) })
}
$coloresEstado = @{ bien = (C 30 140 60); revisar = (C 215 110 0); sin = (C 140 140 150) }
$textosEstado = @{ bien = 'bien'; revisar = 'revisar'; sin = 'sin revisar' }
function Abrir-Skin($n) {
    if ($script:actual) { Volcar-Todo }
    $script:cargando = $true
    if (-not $script:datos.ContainsKey($n)) { Cargar-Skin $n }
    $script:actual = $n
    $e = if ($script:estado.ContainsKey($n)) { $script:estado[$n] } else { 'sin' }
    $lbNombre.Text = "$n   ● $($textosEstado[$e])" + $(if ($script:archivadas -contains $n) { '   (archivada)' } else { '' }); $lbNombre.ForeColor = (C 40 30 60)
    $txFicha.Text = Leer-Ficha $n
    $d = $script:datos[$n]
    Llenar-Lista $frases @($NombresFrases.Keys | Where-Object { $d.Contains($_) -or $_ -ne 'Yo' }) $NombresFrases
    Mostrar-Apps; Mostrar-Otras
    $cbInvitado.Items.Clear(); foreach ($s in $script:orden) { if ($s -ne $n) { [void]$cbInvitado.Items.Add($s) } }
    Mostrar-Charlas
    $mec = @($d.Keys | Where-Object { $CamposFijos -notcontains $_ })
    if ($mec.Count) { if (-not $pestanas.TabPages.Contains($pMeca)) { $pestanas.TabPages.Add($pMeca) }; Llenar-Lista $meca $mec $null }
    elseif ($pestanas.TabPages.Contains($pMeca)) { $pestanas.TabPages.Remove($pMeca); $meca.Clave = $null }
    $script:cargando = $false
    if ($lbCharlas.Items.Count) { Mostrar-Charla }
    Actualizar-Resumen
}
function Rellenar-Arbol {
    $arbol.BeginUpdate(); $arbol.Nodes.Clear()
    foreach ($g in $script:grupos.Keys) {
        $ng = $arbol.Nodes.Add($g); $ng.NodeFont = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold); $ng.ForeColor = (C 90 80 110)
        foreach ($s in $script:grupos[$g].Keys) {
            $e = if ($script:estado.ContainsKey($s)) { $script:estado[$s] } else { 'sin' }
            $nd = $ng.Nodes.Add("● $s"); $nd.Tag = $s; $nd.ForeColor = $coloresEstado[$e]
        }
    }
    $arbol.ExpandAll(); $arbol.EndUpdate()
}

# ---------------------------------------------------------------- EVENTOS
$arbol.Add_AfterSelect({
    $s = $_.Node.Tag
    if ($s -and $s -ne $script:actual) { Abrir-Skin $s }
})
$frases.Lista.Add_SelectedIndexChanged({ if (-not $script:cargando) { Volcar-Lista $frases; Mostrar-Lista $frases } })
$meca.Lista.Add_SelectedIndexChanged({ if (-not $script:cargando) { Volcar-Lista $meca; Mostrar-Lista $meca } })
$lbCharlas.Add_SelectedIndexChanged({ if (-not $script:cargando) { Volcar-Charla; Mostrar-Charla } })
$pestanas.Add_Deselecting({ if (-not $script:cargando -and $script:actual) { Volcar-Todo; Actualizar-Resumen } })
# cambiar el invitado de la charla: sus líneas pasan al nuevo invitado
$cbInvitado.Add_SelectionChangeCommitted({
    if ($script:charlaActual -lt 0) { return }
    Volcar-Charla
    $nuevo = [string]$cbInvitado.SelectedItem; $viejo = $script:invitadoActual
    foreach ($par in $script:charlas[$script:charlaActual]) { if ($par[0] -eq $viejo) { $par[0] = $nuevo } }
    Marcar-Sucio 'charlas'
    $i = $lbCharlas.SelectedIndex; $script:cargando = $true
    $lbCharlas.Items[$i] = Texto-Charla $script:charlas[$script:charlaActual]; $script:cargando = $false
    Mostrar-Charla; Actualizar-Resumen
})
$btNuevaCh.Add_Click({
    if (-not $script:actual) { return }
    Volcar-Charla
    $inv = @($script:orden | Where-Object { $_ -ne $script:actual })[0]
    $nueva = New-Object System.Collections.ArrayList
    [void]$nueva.Add(@($inv, '(escribe aquí lo que dice el invitado)')); [void]$nueva.Add(@($script:actual, '(escribe aquí lo que contesta)'))
    [void]$script:charlas.Add($nueva); Marcar-Sucio 'charlas'
    Mostrar-Charlas; $lbCharlas.SelectedIndex = $lbCharlas.Items.Count - 1
    Actualizar-Resumen
})
$btBorrarCh.Add_Click({
    if ($script:charlaActual -lt 0) { return }
    $r = [System.Windows.Forms.MessageBox]::Show('¿Borrar esta charla? Desaparece para las dos skins.', 'Borrar charla', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    $script:charlas.RemoveAt($script:charlaActual); $script:charlaActual = -1; Marcar-Sucio 'charlas'
    Mostrar-Charlas; if ($lbCharlas.Items.Count) { Mostrar-Charla }; Actualizar-Resumen
})
function Guardar-Todo {
    Volcar-Todo
    foreach ($s in @($script:sucio.Keys)) { if ($script:sucio[$s]) { Guardar-Skin $s } }
    if ($script:charlasSucias) { Guardar-Charlas }
    $script:sucio = @{}; $script:charlasSucias = $false
    Poner-Titulo; Actualizar-Resumen
}
$btGuardar.Add_Click({
    try { Guardar-Todo; [System.Windows.Forms.MessageBox]::Show("Guardado. El panel usará los cambios la próxima vez que se abra.", 'Guardado', 'OK', 'Information') | Out-Null }
    catch { [System.Windows.Forms.MessageBox]::Show("No se ha podido guardar: $_", 'Error', 'OK', 'Error') | Out-Null }
})
$btDeshacer.Add_Click({
    if (-not (Hay-Cambios)) { return }
    $r = [System.Windows.Forms.MessageBox]::Show('¿Deshacer todos los cambios sin guardar (de todas las skins y charlas)?', 'Deshacer', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    $s = $script:actual
    $script:datos = @{}; $script:sucio = @{}; $script:charlasSucias = $false; $script:actual = $null; $script:charlaActual = -1
    $frases.Clave = $null; $meca.Clave = $null
    Cargar-Charlas; Abrir-Skin $s; Poner-Titulo
})
$form.Add_FormClosing({
    if (-not (Hay-Cambios)) { return }
    $r = [System.Windows.Forms.MessageBox]::Show('Hay cambios sin guardar. ¿Guardarlos antes de salir?', 'Salir', 'YesNoCancel', 'Question')
    if ($r -eq 'Cancel') { $_.Cancel = $true } elseif ($r -eq 'Yes') { Guardar-Todo }
})
$form.Add_Shown({
    $split.SplitterDistance = (P 230)
    foreach ($sp in @($frases.Split, $meca.Split, $spCh)) { try { $sp.SplitterDistance = (P 280) } catch {} }
    # abre la primera skin
    if ($arbol.Nodes.Count -and $arbol.Nodes[0].Nodes.Count) { $arbol.SelectedNode = $arbol.Nodes[0].Nodes[0] }
})

# ---------------------------------------------------------------- ARRANQUE
try {
    Leer-Skins; Leer-Estado; Cargar-Charlas; Rellenar-Arbol
} catch {
    [System.Windows.Forms.MessageBox]::Show("No se han podido leer los diálogos: $_", 'Editor de diálogos', 'OK', 'Error') | Out-Null
    return
}
if ($Prueba) { . $Prueba }
[void]$form.ShowDialog()
