# flagship.vim

Flagship provides a Vim status line and tab line that are both easily
customizable by the user and extensible by other plugins.

## Installation

Copy and paste for [pathogen.vim](https://github.com/tpope/vim-pathogen):

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-flagship.git
    vim -u NONE -c "helptags vim-flagship/doc" -c q

While not strictly required, I highly recommend the following options:

    set laststatus=2
    set showtabline=2
    set guioptions-=e

The first two force the status line and tab line to always display, and the
third disables the GUI tab line in favor of the plain text version, enabling
global flags and the tab prefix explained below.

## Extension

Adding a flag from a plugin is a simple matter of calling `Hoist()` with a
scope and function name from a `User Flags` autocommand.  Here's an example
from [fugitive.vim](https://github.com/tpope/vim-fugitive):

    autocmd User Flags call Hoist("buffer", "fugitive#statusline")

You can also do this in your vimrc, for example if a plugin provides a
statusline flag function but does not natively integrate with Flagship.  If
the function isn't defined (e.g., you temporarily disable or permanently
remove the plugin), it will be skipped.  Here's a couple of mine:

    autocmd User Flags call Hoist("window", "SyntasticStatuslineFlag")
    autocmd User Flags call Hoist("global", "%{&ignorecase ? '[IC]' : ''}")

## Customization

The extension API is great for adding flags, but what if you want to change
the core content?  For the status line, Vim already provides a perfectly
adequate `'statusline'` option, and Flagship will use it in constructing its
own.  Customizing your status line is exactly the same with and without
Flagship.

The tab line is another story.  The usual technique (see
`:help setting-tabline`) involves creating a function that cycles through each
tab and assembles a giant format string.  Furthermore, while you can use the
same status line "%" items, they're expanded in the context of the active
window only, rendering most of them worthless for any tab but the current.
Rather than embrace this abomination, Flagship hides it, instead exposing
a `g:tablabel` option which can be assigned to customize the format of a
single tab.  Additionally, you can set `g:tabprefix` to define content to be
inserted before the first tab (assuming you disabled the GUI tab line as
instructed above).

The default tab label is nearly impossible to precisely reconstruct, and I
never really found it useful, so I've taken it a different direction.  Here's
how it would look if you set `g:tablabel` yourself, using a few of the many
helpers available:

    let g:tablabel =
          \ "%N%{flagship#tabmodified()} %{flagship#tabcwds('shorten',',')}"

Here's a breakdown of what's included:

* The tab number, so you never have to hesitate on `gt` invocation.
* One `+` per modified window.  Vim's default shows the status of the tab's
  current window only, which can be misleading.
* A compact representation of the working directories of each window.  For
  determining what project a tab is on, I find this far more useful than the
  filename.

Additionally, I've chosen to prefix the tab line with the Vim GUI server name
(see `:help v:servername`) if available, or the current host name if SSHed.
This only takes a few characters, and I find it to be greatly helpful in
reducing confusion when running multiple instances of Vim.  (Assign
`g:tabprefix` if you don't like it.)

## Self-Promotion

Like flagship.vim?  Follow the repository on
[GitHub](https://github.com/tpope/vim-flagship) and vote for it on
[vim.org](http://www.vim.org/scripts/script.php?script_id=5199).  And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
