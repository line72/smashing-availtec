# Smashing-Availtec

https://github.com/line72/smashing-availtec

(c) 2019 - Marcus Dillavou <line72@line72.net>

Smashing-Availtec is licensed under the terms of the MIT license.

## About

This is a widget for the [Smashing
Dashboard](https://smashing.github.io/) that shows the real time,
estimated arrivals for buses. This works for any bus system that
utilizes [Availtec](https://availtec.com/), such as [Birmingham,
Alabama's.](https://realtimebjcta.availtec.com/)

## Installation

Copy all the files to the appropriate location of your smashing dashboard.

After installing, you first need to configure your stop locations and agency. Edit the `jobs/availtec.rb` file. Make sure you update the `AGENCY_URL` and the `STOP_IDS` list. You can get a stop id by going the the Agency's Availtec site and searching for a stop.

```
AGENCY_URL="https://realtimebjcta.availtec.com/InfoPoint"
STOP_IDS = [2492, 1464, 1430]
```

You then need to add the widget to your dashboard. There are a few important things to know:

1. The `data-sizey` needs to be `2` or there isn't room for the map. You can optionally make the `data-sizex="2"` also.
1. You can have multiple widgets for different buses and/or different stops. Just make sure ALL the needed stop ids are in the `jobs/availtec.rb` and make sure you set the `data-stop_id` and `data-route_id`.

```
<li data-row="1" data-col="3" data-sizex="1" data-sizey="2">
  <div data-id="availtec" data-view="Availtec" data-title="#44" data-sub_title="20th & Morris" data-stop_id=1430 data-route_id=44 data-addclass-danger="isLate"></div>
</li>
```

