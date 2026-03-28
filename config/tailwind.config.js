Plugins::FilePatch.define target: "config/tailwind.config.js" do
  # brand-palette — purple → green
  replace_line containing: '"brand-palette-01": "#121D3A"',
               with: '      "brand-palette-01": "#052E16",'
  replace_line containing: '"brand-palette-02": "#31388D"',
               with: '      "brand-palette-02": "#14532D",'
  replace_line containing: '"brand-palette-03": "#6857D9"',
               with: '      "brand-palette-03": "#15803D",'
  replace_line containing: '"brand-palette-04": "#8686E8"',
               with: '      "brand-palette-04": "#16A34A",'
  replace_line containing: '"brand-palette-05": "#B8C0F4"',
               with: '      "brand-palette-05": "#4ADE80",'
  replace_line containing: '"brand-palette-06": "#D9DEFF"',
               with: '      "brand-palette-06": "#BBF7D0",'
  replace_line containing: '"brand-palette-07": "#EDF1FD"',
               with: '      "brand-palette-07": "#DCFCE7",'
  replace_line containing: '"brand-palette-08": "#F6F8FE"',
               with: '      "brand-palette-08": "#F0FDF4",'

  # purple scale — remap to green scale
  replace_line containing: '900: "#121D3A"',
               with: '          900: "#052E16",'
  replace_line containing: '800: "#1B2C58"',
               with: '          800: "#14532D",'
  replace_line containing: '700: "#31388D"',
               with: '          700: "#166534",'
  replace_line containing: '600: "#6857D9"',
               with: '          600: "#15803D",'
  replace_line containing: '500: "#8686E8"',
               with: '          500: "#16A34A",'
  replace_line containing: '400: "#B8C0F4"',
               with: '          400: "#4ADE80",'
  replace_line containing: '300: "#D9DEFF"',
               with: '          300: "#BBF7D0",'
  replace_line containing: '200: "#EDF1FD"',
               with: '          200: "#DCFCE7",'
  replace_line containing: '100: "#F6F8FE"',
               with: '          100: "#F0FDF4",'
end
