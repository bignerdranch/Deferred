const { promises: fs } = require('fs')

async function replace(path, regexp, replacement) {
  const text = await fs.readFile(path, 'utf-8')
  const replacedText = text.replace(regexp, replacement)
  await fs.writeFile(path, replacedText)
}

async function run() {
  try {
    const version = process.env.INPUT_VERSION
    if (!version) {
      throw new Error("Input required and not supplied: version")
    }
    
    const versionOptimistic = process.env.INPUT_VERSION_OPTIMISTIC
    if (!versionMajor) {
      throw new Error("Input required and not supplied: version_major")
    }

    await Promise.all([
      replace('Configurations/Base.xcconfig', /^(CURRENT_PROJECT_VERSION +=).*$/gm, `$1 ${version}`),
      replace('BNRDeferred.podspec', /^(\s*\w+\.version\s*= )\S*$/gm, `$1"${version}"`),
      replace('Documentation/Guide/Getting Started.md', /^(```\ngithub "bignerdranch\/Deferred" ).*(\n```)$/gm, `$1~> ${versionOptimistic}$2`),
      replace('Documentation/Guide/Getting Started.md', /^(```ruby\npod 'BNRDeferred', ').*('\n```)$/gm, `$1~> ${versionOptimistic}$2`),
      replace('Documentation/Guide/Getting Started.md', /^(\s*\.package\(url: ".*", from: ).*(\),?)$/gm, `$1"${versionOptimistic}.0"$2`)  
    ])
  } catch (error) {
    process.exitCode = 1
    process.stdout.write(`::error::${error.message}\n`)
  }
}

run()
