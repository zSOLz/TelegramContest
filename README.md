# Telegram April 2019 coding contest
The source code of the winner app (1st place) of the contest https://t.me/contest. The app shows best performance among all other apps. This results was reached by using CoreGraphics which renders each frame separately.
Some features you may be interested in:
- All rendering system id driven by **drawRect()** and **DispatchTimer**.  Classes with names *xxxRenderer* used for drawing.
- The rendering of line chart. It draws every line segment separatly. It allow to reduce number of calculations on rendereing stage. I tested about 10 different ways to render line and keep this one as the most efficient.
- Line chart may reduce number of vertices for VERY close coorinates. It cannot be visible but segnificantly increace performance.
- Bar chart is fully optimized to be rendered in most efficient way (I tested about 5 different approaches).
- Percent chart wasn't optimized so it shows the worst performance among all other charts. You may be interesting in transition animation to pie chart.

# Disclaimer
The code was made for contest purposes only. So please DO NOT USE THIS CODE IN PRODUCTION PROJECTS!
Just to warn you, this code contains some ussies like:
- Bad code styling, lots of commented code, grammar mistakes and magic numbers
- Lots of bugs. Full list should be here: https://contest.dev/chart-ios/entry71
- The code wasn't tested in proper way so wrong use may cause random bugs crashes
- A lot of copy pasted blocks of code
- I am not responsible for any issues found in this code. By running the code you automatically agree with it.

# Licence
The code under MIT licence. Use it as you want.
