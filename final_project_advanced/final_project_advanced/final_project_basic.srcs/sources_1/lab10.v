`timescale 1ns / 1ps

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [25:0] snake_clock, apple_clock;
reg signed [10:0]  pos_x [4:0], pos_y[4:0];
reg [9:0] apple_x= 479, apple_y=16*15-1;
wire        snake_region;
wire        boundary_region;
wire        head_reigion;
wire        apple_region;
wire        game_over_region;
wire        apple_1_region, apple_10_region;
reg signed [1:0]  direction_x=1, direction_y=0;
wire  [0:3] btn_level;
wire  [0:3] btn_pressed;
reg   [0:3] prev_btn_level;
reg   game_over= 0, bong= 0, gam;
reg [5:0] apple_cnt= 0;
reg change= 0;
reg [3:0] apple_1, apple_10;
reg [9:0] apple_x_next, apple_y_next;
//reg [0:1130] wall;
reg [0:1130] wall=
{
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00011_111,
39'b000111_11000_00000_00000_00000_01100_00011_111,
39'b000100_00000_00000_00000_00000_00000_00011_111,
39'b000100_00000_00000_00000_00000_00000_00011_111,
39'b000000_00000_00000_00000_00000_00000_00010_000,
39'b000000_00000_00000_00000_00000_00000_00010_000,
39'b000000_00000_00000_00000_00000_00000_00010_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_01111_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_01000_000,
39'b000000_00000_00000_00000_00000_00000_01000_000,
39'b000000_00000_00000_00000_00000_00000_01000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_01000_00000_000,
39'b000000_00000_00000_00000_00000_01000_00000_000,
39'b000000_00000_00000_00000_00000_01000_00000_000,
39'b000000_00000_00000_00000_00000_01000_00000_000,
39'b000000_11111_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_00000_00000_000,
39'b000000_00000_00000_00000_00000_11100_00010_000,
39'b000000_00000_00000_00000_00000_00000_00010_000,
39'b000000_00000_00000_00000_00000_00000_00010_000,
39'b000000_00000_00000_00000_00000_00000_00000_000
};
// declare SRAM control signals
wire [16:0] sram_addr;
wire [11:0] data_in;
wire [11:0] data_out;
wire        sram_we, sram_en;
wire [16:0] sram_addr1;
wire [11:0] data_in1;
wire [11:0] data_out1;
wire        sram_we1, sram_en1;
wire [16:0] sram_addr2;
wire [11:0] data_in2;
wire [11:0] data_out2;
wire        sram_we2, sram_en2;
// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr, pixel_addr1, pixel_addr2;


// Declare the video buffer size
localparam APPLE_W = 16; // video buffer width
localparam APPLE_H = 16; // video buffer height

vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

debounce btn_db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_level[0]));
debounce btn_db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_level[1]));
debounce btn_db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_level[2]));
debounce btn_db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_level[3]));
// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(APPLE_W*APPLE_H))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3] && usr_btn[1]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
sram1 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(320*226))
  ram1 (.clk(clk), .we(sram_we1), .en(sram_en1),
          .addr(sram_addr1), .data_i(data_in1), .data_o(data_out1));

assign sram_we1 = usr_btn[3] && usr_btn[1]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en1 = 1;          // Here, we always enable the SRAM block.
assign sram_addr1 = pixel_addr1;
assign data_in1 = 12'h000; // SRAM is read-only so we tie inputs to zeros.
sram2 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(31*39*10))
  ram2 (.clk(clk), .we(sram_we2), .en(sram_en2),
          .addr(sram_addr2), .data_i(data_in2), .data_o(data_out2));

assign sram_we2 = usr_btn[3] && usr_btn[1]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en2 = 1;          // Here, we always enable the SRAM block.
assign sram_addr2 = pixel_addr2;
assign data_in2 = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 4'b0000;
  else begin
    prev_btn_level[0] <= btn_level[0];
    prev_btn_level[1] <= btn_level[1];
    prev_btn_level[2] <= btn_level[2];
    prev_btn_level[3] <= btn_level[3];
  end
end

assign btn_pressed[0] = (btn_level[0] == 1 && prev_btn_level[0] == 0)? 1 : 0;
assign btn_pressed[1] = (btn_level[1] == 1 && prev_btn_level[1] == 0)? 1 : 0;
assign btn_pressed[2] = (btn_level[2] == 1 && prev_btn_level[2] == 0)? 1 : 0;
assign btn_pressed[3] = (btn_level[3] == 1 && prev_btn_level[3] == 0)? 1 : 0;

always @(posedge clk) begin
    if(~reset_n || bong) begin
        direction_x<= 1;
        direction_y<= 0;
    end
    else if(btn_pressed[0] && direction_x==0 && !game_over) begin //go right
        direction_x<= 1;
        direction_y<= 0;
    end
    else if(btn_pressed[1] && direction_x==0&& !game_over) begin //go left
        direction_x<= -1;
        direction_y<= 0;
    end
    else if(btn_pressed[2] && direction_y==0&& !game_over) begin //go down
        direction_x<= 0;
        direction_y<= 1;
    end
    else if(btn_pressed[3] && direction_y==0&& !game_over) begin //go up
        direction_x<= 0;
        direction_y<= -1;
    end 
    else if(game_over) begin
        direction_x<= 0;
        direction_y<= 0;
    end
    else begin
        direction_x<= direction_x;
        direction_y<= direction_y;
    end
end
// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
                                // in the 640x480 VGA screen
always @(posedge clk) begin
  if (~reset_n || snake_clock[25]==1 || bong) begin
    snake_clock <= 0;
  end
  else
    snake_clock <= snake_clock + 1;
end

always @(posedge clk) begin
    if(~reset_n || bong || change) begin
        pos_x[0]<= 16*6-1;
        pos_x[1]<= 16*5-1;
        pos_x[2]<= 16*4-1;
        pos_x[3]<= 16*3-1;
        pos_x[4]<= 16*2-1;
        pos_y[0]<= 16*15-1;
        pos_y[1]<= 16*15-1;
        pos_y[2]<= 16*15-1;
        pos_y[3]<= 16*15-1;
        pos_y[4]<= 16*15-1;
    end
    else if(snake_clock[25]==1 && !game_over) begin
        pos_x[0]<= pos_x[0]+ direction_x*16;
        pos_x[1]<= pos_x[0];
        pos_x[2]<= pos_x[1];
        pos_x[3]<= pos_x[2];
        pos_x[4]<= pos_x[3];
        pos_y[0]<= pos_y[0]+ direction_y*16;
        pos_y[1]<= pos_y[0];
        pos_y[2]<= pos_y[1];
        pos_y[3]<= pos_y[2];
        pos_y[4]<= pos_y[3];
    end
end

always@ (posedge clk) begin
    if(~reset_n) game_over<= 0;
    else if((pos_x[0]<=15) || (pos_x[0]>=624) || (pos_y[0]<=15) || (pos_y[0]>=464)) begin
        game_over<= 1;
    end
    else if((pos_x[0]==pos_x[3] && pos_y[0]==pos_y[3]) || (pos_x[0]==pos_x[4] && pos_y[0]==pos_y[4]))
        game_over<= 1;
    else if(bong && apple_1==1 && apple_10==0) game_over<=1;
end

always @(posedge clk) begin
    if(~reset_n) bong<= 0;
    else if( wall[(pos_x[0]>>4) + (pos_y[0]>>4)*39] && bong==0) bong<=1;
    else bong<= 0;
end

always@ (posedge clk) begin
    if(~reset_n || apple_clock==25'b10010_11100_01011_00111_10001) begin
        apple_clock<= 0;
    end else
        apple_clock<= apple_clock+1;
end

always@ (posedge clk) begin
    if(~reset_n) begin
        apple_1<= 0;
        apple_10<=0;
        apple_x<= 479;
        apple_y<= 16*17-1;
    end
    else if(bong)begin
        if(apple_1!=0) apple_1<=  apple_1-1;
        else if(apple_1==0 && apple_10!=0)begin
            apple_1<=9;
            apple_10<= apple_10-1;
        end
    end
    else if(apple_x_next!=apple_x && apple_y_next!=apple_y && apple_x_next!=pos_x[1] && apple_y_next!=pos_y[1] && apple_x_next!=pos_x[2] && apple_y_next!=pos_y[2] && apple_x_next!=pos_x[3] && apple_y_next!=pos_y[3] && apple_x_next!=pos_x[4] && apple_y_next!=pos_y[4] && (wall[(apple_x_next>>4) + (apple_y_next>>4)*39]==0)) begin
        apple_x <= apple_x_next;
        apple_y <= apple_y_next;
        if(apple_1!=9) apple_1<= apple_1+1;
        else begin 
            apple_1<= 0;
            apple_10<= apple_10+1;
        end
    end
end

always@ (posedge clk) begin
    if(~reset_n) begin
        apple_x_next<= 479;
        apple_y_next<= 16*17-1;
    end
    else if(bong) begin
        apple_x_next<= apple_x_next;
        apple_y_next<= apple_y_next;
    end
    else if(apple_x==pos_x[0] && apple_y==pos_y[0]) begin
        apple_x_next<= (apple_clock[16:7] %38+2)*16-1;
        apple_y_next<= (apple_clock[10:1] %28+2)*16-1;
    end
    else if((apple_x_next==pos_x[1] && apple_y_next==pos_y[1]) || (apple_x_next==pos_x[2] && apple_y_next==pos_y[2]) || (apple_x_next==pos_x[3] && apple_y_next==pos_y[3]) || (apple_x_next==pos_x[4] && apple_y_next==pos_y[4])) begin
        apple_x_next<= (apple_clock[16:7] %38+2)*16-1;
        apple_y_next<= (apple_clock[10:1] %28+2)*16-1;        
    end
    else if(wall[(apple_x_next>>4) + (apple_y_next>>4)*39]==1) begin
        apple_x_next<= (apple_clock[16:7] %38+2)*16-1;
        apple_y_next<= (apple_clock[10:1] %28+2)*16-1; 
    end
    else begin
        apple_x_next<= apple_x_next;
        apple_y_next<= apple_y_next;
    end
end
always @(posedge clk) begin
    if(~reset_n) begin
         wall[50 +:4]<= 4'b0000;
         wall[250 +:3]<= 3'b000;
         wall[480]<= 0;
         wall[519]<= 0;
         wall[558]<= 0;
         wall[597]<= 0;
         wall[805 +:2]<= 2'b00;
         wall[844 +:2]<= 2'b00;
         wall[996]<= 0;
         wall[1035]<= 0;
         wall[1074]<= 0;
    end
    else if(apple_1==5 && apple_10==0) begin
         wall[50 +:4]<= 4'b1111;
         wall[250 +:3]<= 3'b111;
         wall[480]<= 1;
         wall[519]<= 1;
         wall[558]<= 1;
         wall[597]<= 1;
         wall[805 +:2]<= 2'b11;
         wall[844 +:2]<= 2'b11;
         wall[996]<= 1;
         wall[1035]<= 1;
         wall[1074]<= 1;
     end
 end

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign snake_region = (pixel_x<= pos_x[0] && pixel_y<= pos_y[0] && pixel_x>= pos_x[0]-15 && pixel_y>= pos_y[0]-15) ||
                      (pixel_x<= pos_x[1] && pixel_y<= pos_y[1] && pixel_x>= pos_x[1]-15 && pixel_y>= pos_y[1]-15) ||
                      (pixel_x<= pos_x[2] && pixel_y<= pos_y[2] && pixel_x>= pos_x[2]-15 && pixel_y>= pos_y[2]-15) ||
                      (pixel_x<= pos_x[3] && pixel_y<= pos_y[3] && pixel_x>= pos_x[3]-15 && pixel_y>= pos_y[3]-15) ||
                      (pixel_x<= pos_x[4] && pixel_y<= pos_y[4] && pixel_x>= pos_x[4]-15 && pixel_y>= pos_y[4]-15);
assign boundary_region = (pixel_y<=15) || (pixel_y>=464) || (pixel_x<=15) || (pixel_x>=624);
assign head_region= (pixel_x<= pos_x[0] && pixel_y<= pos_y[0] && pixel_x>= pos_x[0]-15 && pixel_y>= pos_y[0]-15);
assign apple_region= (pixel_x<= apple_x && pixel_y<= apple_y && pixel_x>= apple_x-15 && pixel_y>= apple_y-15);
assign game_over_region= (pixel_x<= 479 && pixel_x>= 160 && pixel_y>=127 && pixel_y<=352);
assign apple_1_region= (pixel_x<= 622 && pixel_x>= 592 && pixel_y>=21 && pixel_y<=59);
assign apple_10_region= (pixel_x<= 590 && pixel_x>= 560 && pixel_y>=21 && pixel_y<=59);

always @ (posedge clk) begin
  if (~reset_n || bong)
    pixel_addr <= 0;
  else if (apple_region)
    pixel_addr <= (pixel_y+15-apple_y)*APPLE_W + (pixel_x+15-apple_x);
  else pixel_addr<= 0;
end
always @ (posedge clk) begin
  if (~reset_n)
    pixel_addr1 <= 0;
  else if (game_over)
    pixel_addr1 <= (pixel_y+225-352)*320 + (pixel_x+319-479);
  else pixel_addr1<= 0;
end

always @ (posedge clk) begin
  if (~reset_n)
    pixel_addr2 <= 0;
  else if (apple_1_region)
    pixel_addr2 <= apple_1*31*39 + (pixel_y+38-59)*31 + (pixel_x+30-622);
  else if (apple_10_region)
    pixel_addr2 <= apple_10*31*39 + (pixel_y+38-59)*31 + (pixel_x+30-590);
  else pixel_addr2<= 0;
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else
    if(game_over && game_over_region && data_out1!=12'h0f0) rgb_next= data_out1;
    else if(head_region) rgb_next= 12'hfff;
    else if(apple_region && data_out!=12'h0f0 && data_out!=12'h000) rgb_next= data_out;
    else if(apple_1_region && data_out2!=12'h0f0) rgb_next= data_out2;
    else if(apple_10_region && data_out2!=12'h0f0) rgb_next= data_out2;
    else if(wall[(pixel_x>>4) + (pixel_y>>4)*39]==1 && game_over) rgb_next= 12'ha00;
    else if(wall[(pixel_x>>4) + (pixel_y>>4)*39]==1) rgb_next= 12'h0a0;
    else if(boundary_region && game_over) rgb_next = 12'hf00;
    else if(boundary_region) rgb_next = 12'h0f0;
    else if(snake_region) rgb_next = 12'h00f;
    else if(pixel_x[4] ^ pixel_y[4]) rgb_next = 0; // RGB value at (pixel_x, pixel_y)
    else rgb_next= 12'h111;
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
