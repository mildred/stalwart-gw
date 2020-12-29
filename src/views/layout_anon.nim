import templates
import ./layout
import ../common

func layout_anon_nav(com: CommonRequest, main: string): string = tmpli html"""
    <main>
      $main
    </main>
  """

func layout_anon*(com: CommonRequest, main, title: string): string =
  result = com.layout(
    title = title,
    main = com.layout_anon_nav(main))


