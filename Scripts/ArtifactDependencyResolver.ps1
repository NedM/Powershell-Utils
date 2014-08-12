$pathToDependenciesFile = (Get-ChildItem dependencies.txt -Recurse).FullName

$dependencies = Get-Content $pathToDependenciesFile | ConvertFrom-Json

# $dependencies.ConfigTool || $dependencies.TcpServer will get the objects we are interested in.

# Get an array of the names of the dependency modules
$moduleNames = ($dependencies | Get-Member -MemberType NoteProperty).Name

# $dependencies.($moduleNames[0]) gets the first module that the project depends on