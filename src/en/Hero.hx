package en;

class Hero extends Entity {
	var ca : dn.heaps.Controller.ControllerAccess;
	var back : HSprite;
	var largeWheel : HSprite;
	var smallWheel : HSprite;
	var turnOverAnim = 0.;

	public function new(e:World.Entity_Hero) {
		super(e.cx, e.cy);
		ca = Main.ME.controller.createAccess("hero");

		spr.set("tractorBase");
		game.scroller.add(spr, Const.DP_HERO);

		back = Assets.tiles.h_get("tractorBack",0, 0.5,1);
		game.scroller.add(back, Const.DP_HERO_BACK);

		largeWheel = Assets.tiles.h_get("wheelLarge",0, 0.5,0.5);
		game.scroller.add(largeWheel, Const.DP_HERO_BACK);

		smallWheel = Assets.tiles.h_get("wheelSmall",0, 0.5,0.5);
		game.scroller.add(smallWheel, Const.DP_HERO_BACK);

		hasCartoonDistorsion = false;

		// var g = new h2d.Graphics(spr);
		// g.beginFill(0x3059ab);
		// g.drawRect(-10,-16,20,16);
	}


	override function getCarriageX():Float {
		return game.cart.footX;
	}

	override function getCarriageY():Float {
		return game.cart.footY;
	}

	override function dispose() {
		super.dispose();

		back.remove();
		largeWheel.remove();
		smallWheel.remove();
		ca.dispose();
		ca = null;
	}

	function autoWalkS(dir:Int, t:Float) {
		this.dir = dir>0 ? 1 : -1;
		cd.setS("autoWalk",t);
	}

	// var autoActions : Array<{ weight:Float, cb:Void->Void }> = [];

	// inline function queueAutoAction(weight:Float, cb:Void->Void) {
	// 	autoActions.push({
	// 		weight: weight,
	// 		cb: cb,
	// 	});
	// }

	function jump() {
		setSquashX(0.6);
		bdy = 0;
		dy = -0.25;
		cd.setS("extraJump",0.15);
		cd.unset("wasOnGround");
	}

	override function onLand() {
		super.onLand();
		setSquashY(0.6);
	}

	override function postUpdate() {
		super.postUpdate();

		var moving = ca.lxValue()!=0;
		var movingOnGround = onGround && moving;

		spr.scaleX *= (1-turnOverAnim*0.7);
		turnOverAnim *= Math.pow(0.8,tmod);

		var t = ftime*0.1 + uid;
		spr.scaleX *= 0.95 + Math.cos(t)*0.05;
		spr.scaleY *= 0.95 + Math.sin(t)*0.05;
		if( !movingOnGround )
			spr.y += -1 + Math.sin(t)*2;

		smallWheel.x = Std.int( footX + dir*9 * (1-turnOverAnim) );
		smallWheel.y = footY - 4 + ( onGround ? 0 : dyTotal>=0.05*tmod ? 2 : -1 );

		largeWheel.x = Std.int( footX - dir*6 * (1-turnOverAnim) );
		largeWheel.y = footY - 6 + ( onGround ? 0 : dyTotal>=0.05*tmod ? 2 : -1 );

		if( movingOnGround ) {
			largeWheel.y-=rnd(0,1);
			smallWheel.y-=rnd(0,1);
			spr.scaleY *= 1 + 0.05*Math.cos(ftime*0.4+uid);
			spr.y += -M.fabs( Math.sin( ftime*0.5+uid)*1 );
		}

		if( movingOnGround && !cd.hasSetS("grass",0.06) )
			fx.grass(footX, footY, -dir);

		if( !cd.hasSetS("smoke", moving ? 0.18 : 0.5 ) )
			fx.tractorSmoke(footX-dir*6, footY-8, -dir);

		back.x = spr.x+1;
		back.y = spr.y;
		back.scaleX = spr.scaleX;
		back.scaleY = spr.scaleY;

		// var t = ftime*0.1 + uid;
		// smallWheel.scaleY = 0.8 + Math.sin(t)*0.2;
	}

	var cliffInsistF = 0.;
	override function update() {
		super.update();

		var spd = 0.016;

		// Jump off cliffs
		if( !onGround && onGroundRecently && ca.lxValue()!=0 && dyTotal>0 && !cd.hasSetS("cliffMiniJump",0.5) )
			dy = -0.11;

		// Walk
		if( ca.leftDist()>0 && !cd.has("autoWalk") ) {
			dx += Math.cos( ca.leftAngle() ) * spd * (1-0.5*cd.getRatio("slowdown")) * tmod;
			var oldDir = dir;
			dir = M.radDistance( ca.leftAngle(), 0 ) <= M.PIHALF ? 1 : -1;

			if( oldDir!=dir )
				turnOverAnim = 1;

			if( onGround && level.hasMark(CliffHigh,cx,cy,dir) )
				cliffInsistF += tmod;

			// Auto jumps
			if( onGround ) {
				// Climb small step
				if( level.hasMark(StepSmall, cx, cy, dir) && sightCheckCase(cx,cy) ) {
					jump();
					autoWalkS(level.getMarkDir(StepHight, cx, cy), 0.3);
					xr = 0.5;
					dy*=0.45;
				}
				// Climb high step
				if( level.hasMark(StepHight, cx, cy, dir) && sightCheckCase(cx,cy) ) {
					jump();
					autoWalkS(level.getMarkDir(StepHight, cx, cy), 0.3);
					xr = 0.5;
				}
			}
		}
		else
			cliffInsistF = 0;

		// Auto walk
		if( cd.has("autoWalk") ) {
			dx += dir * spd * tmod;
		}

		// Brake on cliff
		if( onGround && level.hasMark(CliffHigh, cx,cy, M.sign(dxTotal)) && cliffInsistF<=0.5*Const.FPS ) {
			var cliffXr = ( 0.5 + 0.4*M.sign(dxTotal) );
			var ratio = 1-M.fabs( cliffXr - xr );
			dx *= Math.pow(0.95 - 0.7*ratio,tmod);
		}

		// Bump away from cliffs
		var cliffDir = level.getMarkDir(CliffHigh,cx,cy);
		if( onGround && level.hasMark(CliffHigh,cx,cy) && cliffInsistF<=0 && ( cliffDir==1 && xr>=0.6 || cliffDir==-1 && xr<=0.4 ) ) {
			bump(-cliffDir*0.03, -0.1);
		}

		// Edge grabbing
		if( level.hasMark(EdgeGrab,cx,cy) && !onGround && dyTotal>0 ) {
			var edgeDir = level.getMarkDir(EdgeGrab,cx,cy);
			if( dir==edgeDir && ( edgeDir==1 && xr>=0.3 || edgeDir==-1 && xr<=0.7 ) ) {
			// if( M.sign(ca.lxValue())==edgeDir ) {
				dx = edgeDir * 0.05;
				autoWalkS( edgeDir, 0.1 );
				dy = -0.3;
				xr = 0.5;
				yr = M.fmin(yr,0.4);
				bdy = 0;
			}
		}

		// Jump
		if( ca.aPressed() && ( onGround || onGroundRecently ) ) {
			jump();
		}
		else if( cd.has("extraJump") ) {
			dy += -0.04*tmod;
		}

		// Execute 1 auto-action
		// if( autoActions.length>0 ) {
		// 	var dh = new dn.DecisionHelper(autoActions);
		// 	dh.score( (a)->a.weight );
		// 	dh.getBest().cb();
		// 	autoActions = [];
		// }

		// Grab items
		for(e in en.Item.ALL) {
			if( e.isAlive() && !e.isCarried() && !e.cd.has("heroPickLock") ) {
				if( e.gravityMul==0 && !onGround && distCase(e)<=4 && M.fabs(cx-e.cx)<=2 )
					startCarrying(e);
				else if( distCase(e)<=2.5 )
					startCarrying(e);
			}
		}

		#if debug
		if( ca.isKeyboardPressed(K.BACKSPACE) )
			stopCarryingAnything();
		#end
	}

}