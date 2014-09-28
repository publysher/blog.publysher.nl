---
date: "2012-06-11"
title: "Stencyl Tower Defense Tutorial: Staying Alive"
category: "Stencyl Tower Defense Tutorial"
tags:
  - stencyl
  - stencylworks
  - tutorial
  - flash
  - game development
  - tower defense
description: "Stencyl Tutorial #9 for creating tower defense games"
---

Our Tower Defense game is slowly turning into a real game, but there is still a lot of work to do. For example,
most games are about winning, and therefore about losing. In this part of the tutorial I'm going to work on losing
the game. For now, winning will remain a promise :)

[The result of this part can be seen here](http://www.stencyl.com/game/play/13086); you can also find it on
StencylForge under the name "Publysher – TD Tutorial #9".

Number of Lives
---------------

In order to be able to lose, I will keep track of the number of lives. Every time an enemy reaches the finish line,
the player loses one live. When the player has no more lives remaining, he has lost the game. Of course,
the current number of lives has to be visible so the player knows how he's doing.

Until now, we have only created Actor Behaviors. However, the number of lives of the player is not related to a
specific actor but to the current level. So, this time I will create our first custom Scene Behavior.

**Tip**: there are no rules for choosing between Actor behaviors and Scene behaviors – use your gut feeling,
and don't be afraid to change it later on. You will get better at it over time.

But first some preparations. I started out by copying the Score Font to a new font called Lives Font and changed the
colors to white and red. I also created an actor called "Number of Lives", used
[this heart from iconfinder.com](http://www.iconfinder.com/icondetails/3547/16/favourite_heart_love_package_icon?r=1)
as its default animation and made it a member of the group "Visual Effects".

Now it is time to create a new Design Mode Scene Behavior called "Number of Lives Manager". It will work like this:

1. When the behavior is created, it will draw the Heart icon on the upper left screen;
2. When the scene is redrawn, the behavior will draw the remaining number of lives next to the Heart;
3. The behavior will have a custom block "decrease number of lives by [amount]" – this will decrease the remaining
   number of lives. However, it will also make sure the remaining number of lives is never smaller than zero. When
   the remaining number of lives reaches 0, it will trigger an event called "no\_more_lives". This event will be
   triggered exactly once.

So, we will need a few attributes:

- a Number attribute "Number of Lives" – this will be used to configure the number of lives
- a hidden Number attribute "Current Number of Lives" – this will be used to keep track of the number of lives
  remaining
- a hidden Actor attribute "Number of Lives Actor" – this will be used to keep track of the Heart icon
- a hidden Boolean attribute "No More Lives Triggered?" – this will be used to ensure we will trigger the
  "no\_more_lives" event exactly once.

![](/img/stencyl/step9-1.png)

![](/img/stencyl/step9-2.png)

![](/img/stencyl/step9-3.png)

Attach this behavior to the Test Scene, set the Number of Lives attribute to 10 and play-test your game.

Crossing The Line
-----------------

Now that we have lives, it is time to lose them. Let's start by creating a Finish Line actor and put it in a new
Collision Group called "Finish Line". Using Pencyl, I created a nice black and white checkerboard pattern and added
it to the scene.

![](/img/stencyl/step9-4.png)

Whenever an enemy crosses the finish line, it should cost one live. But how do we detect when an enemy crosses this
line? That's where Stencyl's built-in collision detection can help us.

The first step is to determine the correct collision shape for our actor. Open the Finish Line actor and go to the
Collision tab. Remove the default collision shape by selecting the default box and pressing the Delete button. Then,
using the "Add Box" button, add a box such that it is exactly as large as the finish line:

![](/img/stencyl/step9-5.png)

Now we don't want our enemies to bump into the finish line – we merely want to detect when an enemy crosses the line.
So make sure you tick the box "Is a Sensor?" on the right-hand side.

The last step is to make sure our Finish Line collision group is set to collide with our enemies.

![](/img/stencyl/step9-6.png)

Play the Test Scene again and notice how the new finish line does not seem to have any effect. However,
under the hood a lot is happening.

Losing Lives
------------

Now it's time to actually make use of everything we've set up so far. I'm going to create a new Design Mode Actor
Behavior called "Enemy Reaches Finish". This behavior will work like this:

1. When an enemy collides with the finish line:
   1. distract a certain number of lives from our current number of lives
   2. make sure the enemy becomes invincible
   3. make sure the enemy no longer gives points when killed
   4. add some nice visual feedback

This implies the following attributes:
- a Number attribute called "Number of Lives" – this is the number of lives we will distract from the current number
  of lives when the enemy reaches the finish line. Set the default to 1.
- a hidden Boolean attribute called "Reached FInish Line" – this attribute will be used to ensure we will only collide
  once.

and the following code:

![](/img/stencyl/step9-8.png)

![](/img/stencyl/step9-9.png)

Add this behavior to every enemy, play the game and behold! Enemies crossing the line will now decrease the current
number of lives.

You Lost
--------

When the current number of lives reaches zero, our behavior triggers the no\_more_lives event. Let's use this event
to inform the player about this horrible event. When the player loses, a big You Lose message should appear,
after which the level should restart.

I started out by using my favorite graphics program to create a big You Lost graphic. I then created an actor called
"You Lost Message", and put it in a new collision group called "Messages".

The next step was to create a new Design Mode Actor Behavior called "Message" and attach it to the "You Lost Message".
For now, this behavior consists of a "When Created" block and a custom block called "Show message":

![](/img/stencyl/step9-10.png)

![](/img/stencyl/step9-11.png)

![](/img/stencyl/step9-12.png)

Did you notice anything special? The "show message" block returns the number of seconds it will take to actually show
the message.  This is a small trick to ensure that other behaviors can wait exactly as long as needed for the
animation to complete.

Everything comes together in the final behavior, a Design Mode Scene Behavior called "Player Dies". This behavior has
one custom event block: "when [no\_more_lives] happened" which:

- Ensures that all enemies stand still and can no longer be killed;
- Ensures that the towers stop shooting at enemies;
- Ensures that the enemy spawners stop spawning enemies;
- Ensures that the player can no longer create new towers;
- Shows the You Lost message;
- Reloads the scene;

![](/img/stencyl/step9-16.png)

![](/img/stencyl/step9-15.png)

This behavior was attached to the Test Scene, and playtesting shows the desired result.

A Nasty Bug
-----------

Or did it? As it turns out, the game I created contained a very annoying bug: after reloading the scene,
the enemies fail to show up! At the moment I consider this a bug in Stencyl, and
[I have created a bug report](http://community.stencyl.com/index.php/topic,11178.0.html). Until the bug has been solved,
I have patched the "Spawn Enemies" behavior. Instead of directly modifying the Waves list attribute,
I have added a hidden "Copy of Waves" attributes which gets initialized in the "When created" block.

The "Spawn Enemies" block which was introduced in part 6 now looks like this:

![](/img/stencyl/step9-13.png)

![](/img/stencyl/step9-14.png)

**Tip**: bugs happen, and usually in your own code. But sometimes it is a problem in the framework. In those cases,
do not despair and try to find a workaround.

Wrapping Up
-----------

In this tutorial I have

- Added a new counter to measure the number of remaining lives
- Added a finish line
- Used collision detection to detect when enemies cross the finish line and tied this to the remaining lives
- Created a message to tell the player he lost
- Encountered an interesting Stencyl bug

[The final result can be seen here](http://www.stencyl.com/game/play/13086), and the game can be downloaded from
StencylForge under the name "Publysher – TD Tutorial #9".

Now continue with the next part where the player gets the opportunity to win.
